import QtQuick
import "internal"

Item {
    id: root
    required property Controller controller
    // Use Image.PreserveAspectFit or Image.PreserveAspectCrop. Cells stay square.
    property int fillMode: Image.PreserveAspectFit
    property color tintColor: "#1e1e2e"
    property real tintAmount: 0.16
    property int transitionMs: 50
    readonly property bool animated: controller.healthy && texture.ready
    readonly property bool fallbackReady: still.status === Image.Ready
    readonly property string renderError: texture.renderError
    readonly property real sceneWidth: fillMode === Image.PreserveAspectCrop ? Math.max(width, height * 2) : Math.min(width, height * 2)
    clip: true

    Rectangle {
        anchors.fill: parent
        color: root.controller.frame ? root.controller.frame.ground : "#080b12"
    }
    Image {
        id: still
        anchors.centerIn: parent
        width: root.sceneWidth
        height: width / 2
        source: root.controller.stillSource
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        retainWhileLoading: true
        visible: !root.animated
    }
    SceneTexture {
        id: texture
        anchors.centerIn: parent
        width: root.sceneWidth
        height: width / 2
        packet: root.controller.frame
        transitionMs: Math.max(0, root.transitionMs)
        visible: root.animated
    }
    Rectangle {
        anchors.fill: parent
        color: root.tintColor
        opacity: Math.max(0, Math.min(1, root.tintAmount))
    }
}
