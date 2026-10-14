import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root
    property Controller controller: Controller {}
    property var screens: Quickshell.screens
    property bool visible: true
    property int layer: WlrLayer.Background
    property string namespace: "ascii-wallpaper"
    property int fillMode: Image.PreserveAspectFit
    property color tintColor: "#1e1e2e"
    property real tintAmount: 0.16
    property int transitionMs: 50

    Variants {
        model: root.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            visible: root.visible
            color: "#080b12"
            WlrLayershell.layer: root.layer
            WlrLayershell.namespace: root.namespace
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            SceneView {
                anchors.fill: parent
                controller: root.controller
                fillMode: root.fillMode
                tintColor: root.tintColor
                tintAmount: root.tintAmount
                transitionMs: root.transitionMs
            }
        }
    }
}
