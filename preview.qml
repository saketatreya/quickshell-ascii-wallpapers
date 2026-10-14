import QtQuick
import Quickshell
import "AsciiWallpaper" as Ascii

ShellRoot {
    Ascii.Controller { id: scenes; scene: "aurora-fjord"; cycling: false }
    FloatingWindow {
        title: "ASCII scene · embedded view"
        implicitWidth: 960
        implicitHeight: 480
        Ascii.SceneView { anchors.fill: parent; controller: scenes; tintAmount: 0 }
    }
    Ascii.Ipc { controller: scenes }
}
