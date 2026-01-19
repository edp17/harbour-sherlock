// SherlockImageProvider.cpp
#include "SherlockImageProvider.h"
#include "SherlockEngine.h"

SherlockImageProvider::SherlockImageProvider(SherlockEngine *engine)
    : QQuickImageProvider(QQuickImageProvider::Image),
      m_engine(engine)
{
}

QImage SherlockImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    // Accept IDs like:
    //   "32/r0_i3?e=1"
    //   "16/21?e=5"
    //
    // We ignore query params (everything after '?').

    QString clean = id;
    const int q = clean.indexOf('?');
    if (q >= 0)
        clean = clean.left(q);

    // Split "32/r0_i3" -> ["32", "r0_i3"]
    // Split "32/21"    -> ["32", "21"]
    const QStringList parts = clean.split('/', QString::SkipEmptyParts);

    int px = (requestedSize.width() > 0) ? requestedSize.width() : 64;
    if (parts.size() >= 1) {
        bool okPx = false;
        const int parsedPx = parts[0].toInt(&okPx);
        if (okPx && (parsedPx == 16 || parsedPx == 32 || parsedPx == 64))
            px = parsedPx;
    }

    int row = -1;
    int item = -1;

    if (parts.size() >= 2) {
        const QString token = parts[1];

        if (token.startsWith('r')) {
            // "r<row>_i<item>"
            const QStringList kv = token.split('_', QString::SkipEmptyParts);
            for (const QString &p : kv) {
                if (p.startsWith('r'))
                    row = p.mid(1).toInt();
                else if (p.startsWith('i'))
                    item = p.mid(1).toInt();
            }
        } else {
            // numeric one-based index: 1..n*n
            bool okIdx = false;
            const int idx1 = token.toInt(&okIdx);
            if (okIdx && m_engine) {
                const int n = m_engine->size();
                const int k = idx1 - 1;
                if (k >= 0 && k < n*n) {
                    row  = k / n;
                    item = k % n;
                }
            }
        }
    }

    QImage img = m_engine ? m_engine->iconFor(row, item, px) : QImage();
    if (size) *size = img.size();
    return img;
}
