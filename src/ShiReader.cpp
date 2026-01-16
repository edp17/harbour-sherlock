#include "ShiReader.h"

#include <QFile>
#include <QFileInfo>
#include <QDataStream>
#include <QPainter>
#include <QDir>
#include <utility>

static QString hexPreview(const QByteArray &b, int maxBytes)
{
    const int n = qMin(maxBytes, b.size());
    QString out;
    out.reserve(n * 3);
    for (int i = 0; i < n; ++i) {
        const unsigned v = static_cast<unsigned char>(b.at(i));
        out += QString("%1 ").arg(v, 2, 16, QLatin1Char('0'));
    }
    return out.trimmed();
}

static QVector<QRgb> tryExtractPalette16(const QByteArray &bytes, int headerSize)
{
    // Search the header for 16*3 bytes that look like a VGA DAC palette (0..63).
    const int start = 8;
    const int end = headerSize - 48;
    int bestOff = -1;
    int bestScore = -1;

    for (int off = start; off <= end; ++off) {
        int score = 0;
        int nonZero = 0;
        int maxv = 0;

        for (int i = 0; i < 48; ++i) {
            const int v = (unsigned char)bytes[off + i];
            maxv = qMax(maxv, v);
            if (v != 0) nonZero++;
        }

        // Prefer ranges that look like 6-bit VGA palette (0..63) and have variety.
        if (maxv <= 63) score += 50;
        score += nonZero; // more variety = better

        if (score > bestScore) {
            bestScore = score;
            bestOff = off;
        }
    }

    QVector<QRgb> pal;
    if (bestOff < 0) return pal;

    pal.reserve(16);
    for (int i = 0; i < 16; ++i) {
        int r = (unsigned char)bytes[bestOff + i*3 + 0];
        int g = (unsigned char)bytes[bestOff + i*3 + 1];
        int b = (unsigned char)bytes[bestOff + i*3 + 2];

        // Scale 0..63 -> 0..255
        r = r * 255 / 63;
        g = g * 255 / 63;
        b = b * 255 / 63;

        pal.push_back(qRgb(r, g, b));
    }
    return pal;
}

QVector<QRgb> ShiReader::ega16()
{
    // Classic EGA 16-color palette (starter; can be swapped later)
    return {
        qRgba(0x00,0x00,0x00,0x00), // 0 transparent instead of black
        qRgb(0x00,0x00,0xAA), // 1 blue
        qRgb(0x00,0xAA,0x00), // 2 green
        qRgb(0x00,0xAA,0xAA), // 3 cyan
        qRgb(0xAA,0x00,0x00), // 4 red
        qRgb(0xAA,0x00,0xAA), // 5 magenta
        qRgb(0xAA,0x55,0x00), // 6 brown
        qRgb(0xAA,0xAA,0xAA), // 7 light gray
        qRgb(0x55,0x55,0x55), // 8 dark gray
        qRgb(0x55,0x55,0xFF), // 9 light blue
        qRgb(0x55,0xFF,0x55), // 10 light green
        qRgb(0x55,0xFF,0xFF), // 11 light cyan
        qRgb(0xFF,0x55,0x55), // 12 light red
        qRgb(0xFF,0x55,0xFF), // 13 light magenta
        qRgb(0xFF,0xFF,0x55), // 14 yellow
        qRgb(0xFF,0xFF,0xFF)  // 15 white
    };
}

static QImage decode4bppChunky(const uchar *src, int w, int h,
                               const QVector<QRgb> &pal,
                               bool highNibbleFirst,
                               bool swap16pxHalves,
                               bool rowByteReverse,
                               bool nibbleSwap)
{
    // w must be even for 4bpp packed (2 pixels per byte)
    QImage img(w, h, QImage::Format_ARGB32);

    const int bytesPerRow = w / 2; // 2 pixels per byte
    for (int y = 0; y < h; ++y) {
        QRgb *out = reinterpret_cast<QRgb*>(img.scanLine(y));
        const uchar *row = src + y * bytesPerRow;

        for (int x = 0; x < w; ++x) {
            int xr = x;

            // Optional: swap 16px halves (0..15 <-> 16..31) for 32px-wide images
            if (swap16pxHalves && w == 32) {
                xr = (x < 16) ? (x + 16) : (x - 16);
            }

            int byteIndex = xr / 2;        // 0..15 for w=32
            int inBytePos = xr & 1;        // 0=first pixel, 1=second pixel

            // Optional: reverse the byte order within the row
            if (rowByteReverse) {
                byteIndex = (bytesPerRow - 1) - byteIndex;
            }

            const uchar b = row[byteIndex];

            // Extract the pixel nibble
            int n0 = (b >> 4) & 0x0F;
            int n1 = (b >> 0) & 0x0F;

            if (!highNibbleFirst) {
                // treat low nibble as first pixel
                std::swap(n0, n1);
            }
            if (nibbleSwap) {
                // swap nibbles unconditionally (extra toggle)
                std::swap(n0, n1);
            }

            const int idx = (inBytePos == 0) ? n0 : n1;
            out[x] = pal[idx & 0x0F];
        }
    }

    return img;
}

QImage ShiReader::decode4bppPlanar(const uchar *src, int w, int h,
                                   const QVector<QRgb> &pal,
                                   bool msbFirst,
                                   bool planesReversed,
                                   bool rowInterleaved,
                                   bool rowByteSwap16,
                                   bool rowByteReverse,
                                   bool rowHalfSwap16px,
                                   bool swapPlane12,
                                   bool ySwap16,
                                   bool yEvenOdd,
                                   bool yFlip)
{
    const int bytesPerRow = w / 8;           // 32->4, 16->2
    const int planeSize   = bytesPerRow * h; // 32x16: 64, 32x32: 128

    QImage img(w, h, QImage::Format_ARGB32);

    for (int y = 0; y < h; ++y) {
        int yRead = y;

        if (ySwap16 && h == 32) {
            yRead = yRead ^ 16; // swap 0..15 with 16..31
        }
        if (yEvenOdd) {
            yRead = (yRead >> 1) + ((yRead & 1) ? (h >> 1) : 0);
        }
        if (yFlip) {
            yRead = (h - 1) - yRead;
        }

        QRgb *out = reinterpret_cast<QRgb*>(img.scanLine(y));

        for (int x = 0; x < w; ++x) {
            int byteInRow = (x / 8);

            // 32px only: swap 16px halves (bytes 0,1 with 2,3)
            if (rowHalfSwap16px && bytesPerRow == 4) {
                byteInRow = (byteInRow < 2) ? (byteInRow + 2) : (byteInRow - 2);
            }

            // Reverse entire row byte order: 0..3 -> 3..0 (or 0..1 -> 1..0)
            if (rowByteReverse) {
                byteInRow = (bytesPerRow - 1) - byteInRow;
            }

            // Swap bytes within each 16-bit word: 0 1 2 3 -> 1 0 3 2
            if (rowByteSwap16) {
                byteInRow ^= 1;
            }

            const uchar mask = msbFirst ? uchar(0x80u >> (x & 7))
                                        : uchar(0x01u << (x & 7));

            int colorIndex = 0;

            for (int p = 0; p < 4; ++p) {
                int plane = planesReversed ? (3 - p) : p;

                if (swapPlane12) {
                    if (plane == 1) plane = 2;
                    else if (plane == 2) plane = 1;
                }

                int offset;
                if (!rowInterleaved) {
                    offset = plane * planeSize + (yRead * bytesPerRow + byteInRow);
                } else {
                    const int rowBlock = 4 * bytesPerRow; // planes packed per row
                    offset = yRead * rowBlock + plane * bytesPerRow + byteInRow;
                }

                const uchar b = src[offset];
                if (b & mask) colorIndex |= (1 << p);
            }

            out[x] = pal[colorIndex & 0x0F];
        }
    }

    return img;
}

ShiReader::Result ShiReader::tryLoad(const QString &path)
{
    Result r;

    QFileInfo fi(path);
    if (!fi.exists() || !fi.isFile()) {
        r.diagnostic = QStringLiteral("[ShiReader] File not found.");
        return r;
    }

    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        r.diagnostic = QStringLiteral("[ShiReader] Could not open file for reading.");
        return r;
    }

    const QByteArray bytes = f.readAll();
    const qint64 size = bytes.size();

    r.diagnostic =
        QStringLiteral("[ShiReader] sherlock.shi diagnostics\n")
        + QStringLiteral("  Path: %1\n").arg(path)
        + QStringLiteral("  Size: %1 bytes\n").arg(size)
        + QStringLiteral("  Head(256): %1\n").arg(hexPreview(bytes.left(256), 256));

    if (size < 8) {
        r.diagnostic += QStringLiteral("  Status: too small.\n");
        return r;
    }

    QDataStream ds(bytes);
    ds.setByteOrder(QDataStream::LittleEndian);

    quint16 bpp = 0, unknown = 0, w = 0, h = 0;
    ds >> bpp >> unknown >> w >> h;

    r.bpp = int(bpp);
    r.w = int(w);
    r.h = int(h);

    r.diagnostic += QStringLiteral("  Parsed: bpp=%1 unknown=%2 w=%3 h=%4\n")
                        .arg(r.bpp).arg(int(unknown)).arg(r.w).arg(r.h);

    if (r.bpp != 4 || r.w != 32 || r.h != 32) {
        r.diagnostic += QStringLiteral("  Status: unsupported (expected 4bpp, 32x32).\n");
        return r;
    }

    const int fullW = r.w;               // 32
    const int fullH = r.h / 2;           // 16  (treat “full” as 32x16 frame)
    const int frameBytes = (fullW * fullH * r.bpp) / 8; // 32*16*4/8 = 256

    const int halfW = r.w / 2;           // 16
    const int halfH = r.h / 2;           // 16
    const int halfBytes = (halfW * halfH * r.bpp) / 8; // 128

    const int recordBytes = frameBytes + frameBytes + halfBytes; // 256+256+128 = 640

    // Heuristic: many Sherlock SHI files appear to have a 240-byte header before 37 records.
    int headerSize = -1;
    int count = -1;

    if (size >= 240 && ((size - 240) % recordBytes) == 0) {
        headerSize = 240;
        count = int((size - headerSize) / recordBytes);
    } else if (size >= 8 && ((size - 8) % recordBytes) == 0) {
        headerSize = 8;
        count = int((size - headerSize) / recordBytes);
    }

    r.diagnostic += QStringLiteral("  Guess: frameBytes=%1 halfBytes=%2 recordBytes=%3\n")
                        .arg(frameBytes).arg(halfBytes).arg(recordBytes);

    if (headerSize < 0 || count <= 0) {
        r.diagnostic += QStringLiteral("  Status: could not determine header/record layout.\n");
        return r;
    }

    r.diagnostic += QStringLiteral("  Layout: headerSize=%1 count=%2\n").arg(headerSize).arg(count);

    // Keep in sync with the flags in the decode loop
    QVector<QRgb> pal = tryExtractPalette16(bytes, headerSize);
    if (pal.size() != 16) pal = ega16();
    r.diagnostic += QStringLiteral("  Palette: %1\n").arg(pal.size() == 16 ? "header" : "ega16");

    r.full.reserve(count);
    r.half.reserve(count);

    const uchar *p = reinterpret_cast<const uchar*>(bytes.constData());

    // Decode flags (tweak these while testing)
    const bool msbFirst = true;
    const bool planesReversed = false;
    const bool rowInterleaved = true;

    const bool rowByteSwap16 = false;
    const bool rowByteReverse = false;
    const bool rowHalfSwap16px = true;

    const bool swapPlane12 = true;
    const bool ySwap16 = true;
    const bool yEvenOdd = false;

    r.diagnostic += QStringLiteral(
    "  DecodeFlags: msbFirst=%1 planesReversed=%2 rowInterleaved=%3 rowByteSwap16=%4 rowByteReverse=%5 rowHalfSwap16px=%6 swapPlane12=%7 ySwap16=%8 yEvenOdd=%9\n")
    .arg(msbFirst).arg(planesReversed).arg(rowInterleaved).arg(rowByteSwap16).arg(rowByteReverse).arg(rowHalfSwap16px).arg(swapPlane12).arg(ySwap16).arg(yEvenOdd);

auto compose32x32 = [](const QImage &top32x16, const QImage &bot32x16, bool swapTopBottom) -> QImage {
    QImage dst(32, 32, QImage::Format_ARGB32);
    dst.fill(qRgba(0,0,0,0));
    QPainter pp(&dst);
    if (!swapTopBottom) {
        pp.drawImage(0, 0,  top32x16);
        pp.drawImage(0, 16, bot32x16);
    } else {
        pp.drawImage(0, 0,  bot32x16);
        pp.drawImage(0, 16, top32x16);
    }
    return dst;
};

    // --- DEBUG: dump 128 decode variants for record 1, frameA (32x16), padded to 32x32 ---
    {
        const int recIndex = 1; // 0 is often blank; 1 is usually a visible icon
        const int base = headerSize + recIndex * recordBytes;

        if (base >= 0 && base + 2*frameBytes <= size) {
            QVector<QImage> thumbs;
            QVector<QString> labels;
            thumbs.reserve(32);
            labels.reserve(32);

            // Chunky (packed-nibble) brute force: 2^5 = 32 variants
            for (int swapTopBottom = 0; swapTopBottom <= 1; ++swapTopBottom) {
                for (int highNibbleFirst = 0; highNibbleFirst <= 1; ++highNibbleFirst) {
                    for (int swap16pxHalves = 0; swap16pxHalves <= 1; ++swap16pxHalves) {
                        for (int rowByteReverse = 0; rowByteReverse <= 1; ++rowByteReverse) {
                            for (int nibbleSwap = 0; nibbleSwap <= 1; ++nibbleSwap) {

                                const QImage half0 = decode4bppChunky(
                                    p + base,
                                    fullW, fullH,
                                    pal,
                                    bool(highNibbleFirst),
                                    bool(swap16pxHalves),
                                    bool(rowByteReverse),
                                    bool(nibbleSwap)
                                );

                                const QImage half1 = decode4bppChunky(
                                    p + base + frameBytes,
                                    fullW, fullH,
                                    pal,
                                    bool(highNibbleFirst),
                                    bool(swap16pxHalves),
                                    bool(rowByteReverse),
                                    bool(nibbleSwap)
                                );

                                thumbs.push_back(compose32x32(half0, half1, bool(swapTopBottom)));

                                labels.push_back(QStringLiteral("TB%1 HN%2 HS%3 BR%4 NS%5")
                                                 .arg(swapTopBottom)
                                                 .arg(highNibbleFirst)
                                                 .arg(swap16pxHalves)
                                                 .arg(rowByteReverse)
                                                 .arg(nibbleSwap));
                            }
                        }
                    }
                }
            }

            // Draw contact sheet: 16 columns x 2 rows (32 variants)
            const int cols = 16;
            const int rows = 2;

            const int cellW = 96;
            const int cellH = 112;

            QImage sheet(cols * cellW, rows * cellH, QImage::Format_ARGB32_Premultiplied);
            sheet.fill(qRgba(0, 0, 0, 255));

            QPainter painter(&sheet);
            painter.setRenderHint(QPainter::TextAntialiasing, true);

            QFont font = painter.font();
            font.setPixelSize(12);
            painter.setFont(font);

            for (int i = 0; i < thumbs.size(); ++i) {
                const int cx = (i % cols) * cellW;
                const int cy = (i / cols) * cellH;

                painter.fillRect(QRect(cx, cy, cellW, cellH), QColor(30, 30, 30, 255));

                painter.setPen(Qt::white);
                painter.drawText(QRect(cx + 6, cy + 4, cellW - 12, 18),
                                 Qt::AlignLeft | Qt::AlignVCenter,
                                 labels[i]);

                const QImage thumb = thumbs[i].scaled(80, 80, Qt::KeepAspectRatio, Qt::FastTransformation);
                painter.drawImage(cx + (cellW - thumb.width()) / 2, cy + 24, thumb);
            }

            painter.end();

            const QString outPath =
                QDir(QFileInfo(path).absolutePath()).filePath(QStringLiteral("decode_variants.png"));

            sheet.save(outPath, "PNG");

            r.diagnostic += QStringLiteral("  Wrote: decode_variants.png (32 variants, CHUNKY halves)\n");
        } else {
            r.diagnostic += QStringLiteral("  DEBUG: could not dump variants (record/frame out of bounds)\n");
        }
    }
    // --- END DEBUG ---

for (int i = 0; i < count; ++i) {
    const int base = headerSize + i * recordBytes;
    if (base + recordBytes > size) break;

    // decode the two 32x16 halves
    const QImage a = decode4bppPlanar(p + base,
                                      fullW, fullH,
                                      pal,
                                      msbFirst,
                                      planesReversed,
                                      rowInterleaved,
                                      rowByteSwap16,
                                      rowByteReverse,
                                      rowHalfSwap16px,
                                      swapPlane12,
                                      ySwap16,
                                      yEvenOdd,
                                      /*yFlip*/ false);

    const QImage b = decode4bppPlanar(p + base + frameBytes,
                                      fullW, fullH,
                                      pal,
                                      msbFirst,
                                      planesReversed,
                                      rowInterleaved,
                                      rowByteSwap16,
                                      rowByteReverse,
                                      rowHalfSwap16px,
                                      swapPlane12,
                                      ySwap16,
                                      yEvenOdd,
                                      /*yFlip*/ false);

    // store as true 32x32
    r.full.push_back(compose32x32(a, b, /*swapTopBottom*/ false));
}

    r.diagnostic += QStringLiteral("  Decoded: full=%1 half=%2\n").arg(r.full.size()).arg(r.half.size());

    // For the DOS image set: we expect at least 37 images (36 + empty).
    if (r.full.size() < 37) {
        r.diagnostic += QStringLiteral("  Status: decoded, but count is lower than expected (need >=37).\n");
        r.ok = false;
        return r;
    }


    r.ok = true;
    r.diagnostic += QStringLiteral("  Status: OK.\n");
    return r;
}
