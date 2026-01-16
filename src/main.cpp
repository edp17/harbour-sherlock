#include <sailfishapp.h>

#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <QtQml>

#include "SherlockEngine.h"
#include "SherlockImageProvider.h"

int main(int argc, char *argv[])
{
    QGuiApplication *app = SailfishApp::application(argc, argv);
    QQuickView *view = SailfishApp::createView();

    // ADD THIS (enables SherlockEngine.Generated / SherlockEngine.Shi in QML)
    qmlRegisterUncreatableType<SherlockEngine>(
        "Harbour.Sherlock", 1, 0, "SherlockEngine",
        "Enum container"
    );

    SherlockEngine engine;
    view->engine()->addImageProvider(QStringLiteral("sherlock"), new SherlockImageProvider(&engine));
    view->rootContext()->setContextProperty(QStringLiteral("sherlockEngine"), &engine);
    view->setSource(SailfishApp::pathTo(QStringLiteral("qml/main.qml")));
    view->show();
    return app->exec();
}
