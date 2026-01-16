import QtQuick 2.6
import Sailfish.Silica 1.0

import "pages" as Pages
import "cover" as Cover

ApplicationWindow
{
    initialPage: Component { Pages.GamePage {} }
    cover: Component { Cover.CoverPage {} }
}
