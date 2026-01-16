// SherlockImageProvider.h
#pragma once

#include <QQuickImageProvider>

class SherlockEngine;

class SherlockImageProvider : public QQuickImageProvider
{
public:
    explicit SherlockImageProvider(SherlockEngine *engine);

    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

private:
    SherlockEngine *m_engine {nullptr};
};
