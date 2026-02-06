// SherlockImageProvider.cpp
#include "SherlockImageProvider.h"
#include "SherlockEngine.h"
#include <QDebug>

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

    // 1) Remove cache-buster query (e.g. "?e=1")
    QString clean = id;
    const int qpos = clean.indexOf('?');
    if (qpos >= 0)
        clean = clean.left(qpos);

    int px = (requestedSize.width() > 0) ? requestedSize.width() : 64;

    int row = -1;
    int item = -1;

    // 2) New format used by your QML: "<px>/<oneBasedIndex>"
    //    Example: "32/12"
    const QStringList parts = clean.split('/', QString::SkipEmptyParts);
    if (parts.size() == 2) {
        const int pxFromId = parts[0].toInt();
        const int oneBased = parts[1].toInt();

        if (requestedSize.width() <= 0 && pxFromId > 0)
            px = pxFromId;

        const int n = m_engine->size();
        if (oneBased >= 1 && oneBased <= n * n) {
            const int zero = oneBased - 1;
            row  = zero / n;
            item = zero % n;
        }
    } else {
        // 3) Legacy format: "r<row>_i<item>"
        //    Example: "r0_i3"
        const QStringList legacy = clean.split('_', QString::SkipEmptyParts);
        for (const QString &p : legacy) {
            if (p.startsWith('r'))
                row = p.mid(1).toInt();
            else if (p.startsWith('i'))
                item = p.mid(1).toInt();
        }
    }

    QImage img = m_engine->iconFor(row, item, px);
    if (size) *size = img.size();
//qDebug() << "[sherlock provider]" << id << "-> clean" << clean << "row" << row << "item" << item << "px" << px << "img" << img.size();
    return img;
}
