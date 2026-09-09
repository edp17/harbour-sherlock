#include <sailfishapp.h>

#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <QLocale>
#include <QTranslator>
#include <QtQml>

#include "SherlockEngine.h"
#include "SherlockImageProvider.h"

int main(int argc, char *argv[])
{
    QGuiApplication *app = SailfishApp::application(argc, argv);
    app->setOrganizationName(QStringLiteral("edp17"));
    app->setApplicationName(QStringLiteral("harbour-sherlock"));
    app->setApplicationVersion(QStringLiteral("0.2.0"));
    QQuickView *view = SailfishApp::createView();

    QTranslator translator;
    const QString translationDirectory = SailfishApp::pathTo(
        QStringLiteral("translations")).toLocalFile();
    if (translator.load(QLocale(), QStringLiteral("harbour-sherlock"),
                        QStringLiteral("-"), translationDirectory)) {
        app->installTranslator(&translator);
    }

    // Expose the enum values used by QML without allowing QML to construct
    // another engine instance.
    qmlRegisterUncreatableType<SherlockEngine>(
        "Harbour.Sherlock", 1, 0, "SherlockEngine",
        "Enum container"
    );

    SherlockEngine engine;
    engine.setIconThemeRoot(SailfishApp::pathTo(
        QStringLiteral("qml/assets/generated_icons")).toLocalFile());
    view->engine()->addImageProvider(QStringLiteral("sherlock"), new SherlockImageProvider(&engine));
    view->rootContext()->setContextProperty(QStringLiteral("sherlockEngine"), &engine);
    view->setSource(SailfishApp::pathTo(QStringLiteral("qml/main.qml")));
    view->show();
    return app->exec();
}
