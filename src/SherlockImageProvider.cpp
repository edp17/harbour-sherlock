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
    if (!m_engine) {
        if (size) *size = QSize();
        return QImage();
    }

    // Strip query string (?e=...)
    QString clean = id;
    const int q = clean.indexOf('?');
    if (q >= 0)
        clean = clean.left(q);

    // Expected formats:
    //  - "32/21"  (pixelSize/oneBasedIndex)
    //  - "16/21"
    const QStringList parts = clean.split('/', QString::SkipEmptyParts);
    if (parts.size() != 2) {
        if (size) *size = QSize();
        return QImage();
    }

    bool ok1 = false, ok2 = false;
    const int pxFromId = parts[0].toInt(&ok1);
    const int oneBased = parts[1].toInt(&ok2);

    if (!ok1 || !ok2 || oneBased <= 0) {
        if (size) *size = QSize();
        return QImage();
    }

    const int n = m_engine->size();
    const int zero = oneBased - 1;
    const int row = zero / n;
    const int item = zero % n;

    const int px = (requestedSize.width() > 0) ? requestedSize.width() : pxFromId;

    QImage img = m_engine->iconFor(row, item, px);

    if (size) *size = img.size();
    return img;
}
