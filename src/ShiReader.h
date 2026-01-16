#pragma once

#include <QString>
#include <QVector>
#include <QImage>

class ShiReader
{
public:
    struct Result {
        bool ok {false};
        QString diagnostic;

        int bpp {0};
        int w {0};
        int h {0};

        QVector<QImage> full; // 32x32
        QVector<QImage> half; // 16x16 (if present)
    };

    Result tryLoad(const QString &path);

private:
    static QVector<QRgb> ega16();
    QImage decode4bppPlanar(const uchar *src, int w, int h,
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
                        bool yFlip);
};
