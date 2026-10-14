import QtQuick

Item {
    id: root
    property var packet: null
    property int transitionMs: 50
    readonly property int columns: 200
    readonly property int rows: 100
    // Keep the displayed texture intact while the other slot decodes/uploads.
    // Changing the source of a texture currently sampled by ShaderEffect can
    // otherwise expose an empty texture for one compositor frame.
    property int front: -1
    property int preparing: -1
    property var pending: null
    property real blend: 0
    property string textureError: ""
    property color groundA: "#080b12"
    property color groundB: "#080b12"
    readonly property bool ready: front >= 0 && glyphs.status === Image.Ready && effect.status !== ShaderEffect.Error && GraphicsInfo.api !== GraphicsInfo.Software
    readonly property string renderError: effect.status === ShaderEffect.Error ? effect.log : textureError

    function enqueue() {
        if (!packet || !packet.grid || !packet.palette) return;
        pending = packet;
        prepare();
    }
    function prepare() {
        if (!pending || preparing >= 0 || fade.running) return;
        const packet = pending;
        pending = null;
        preparing = front === 0 ? 1 : 0;
        if (preparing === 0) {
            groundA = packet.ground;
            paletteA.source = packet.palette;
            gridA.source = packet.grid;
        } else {
            groundB = packet.ground;
            paletteB.source = packet.palette;
            gridB.source = packet.grid;
        }
        Qt.callLater(checkPrepared);
    }
    function checkPrepared() {
        if (preparing < 0 || commit.running) return;
        const grid = preparing === 0 ? gridA : gridB;
        const palette = preparing === 0 ? paletteA : paletteB;
        if (grid.status === Image.Error || palette.status === Image.Error) {
            textureError = "Could not decode a frame texture";
            preparing = -1;
            Qt.callLater(prepare);
        } else if (grid.status === Image.Ready && palette.status === Image.Ready) {
            textureError = "";
            commit.start();
        }
    }
    onPacketChanged: Qt.callLater(enqueue)
    Component.onCompleted: Qt.callLater(enqueue)

    Image { id: gridA; visible: false; cache: false; smooth: false; retainWhileLoading: true; onStatusChanged: Qt.callLater(root.checkPrepared) }
    Image { id: gridB; visible: false; cache: false; smooth: false; retainWhileLoading: true; onStatusChanged: Qt.callLater(root.checkPrepared) }
    Image { id: paletteA; visible: false; smooth: false; retainWhileLoading: true; onStatusChanged: Qt.callLater(root.checkPrepared) }
    Image { id: paletteB; visible: false; smooth: false; retainWhileLoading: true; onStatusChanged: Qt.callLater(root.checkPrepared) }
    Image { id: glyphs; source: Qt.resolvedUrl("../assets/glyphs.png"); visible: false; smooth: true }
    Timer {
        id: commit
        // Allow one scene-graph synchronization before showing the new slot.
        interval: 16
        onTriggered: {
            if (root.front < 0) {
                gridB.source = gridA.source;
                paletteB.source = paletteA.source;
                root.groundB = root.groundA;
                root.front = 0;
                root.preparing = -1;
                Qt.callLater(root.prepare);
                return;
            }
            root.front = root.preparing;
            root.preparing = -1;
            fade.to = root.front;
            fade.start();
        }
    }
    NumberAnimation {
        id: fade
        target: root
        property: "blend"
        duration: root.transitionMs
        onFinished: Qt.callLater(root.prepare)
    }
    ShaderEffect {
        id: effect
        anchors.fill: parent
        visible: root.ready
        property var gridTextureA: gridA
        property var gridTextureB: gridB
        property var glyphTexture: glyphs
        property var paletteTextureA: paletteA
        property var paletteTextureB: paletteB
        property color groundColorA: root.groundA
        property color groundColorB: root.groundB
        property vector2d gridSize: Qt.vector2d(root.columns, root.rows)
        property real frameBlend: root.blend
        fragmentShader: Qt.resolvedUrl("../assets/scene.frag.qsb")
        blending: false
    }
}
