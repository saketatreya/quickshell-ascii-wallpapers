import QtQuick
import Quickshell
import "../AsciiWallpaper" as Ascii

ShellRoot {
    id: root
    property int captures: 0
    property bool capturing: false
    readonly property bool software: Quickshell.env("ASCII_TEST_SOFTWARE") === "1"
    Ascii.Controller { id: scenes; scene: "varanasi-ghats"; cycling: false }
    FloatingWindow {
        visible: true
        title: "ASCII wallpaper rendering check"
        implicitWidth: 800
        implicitHeight: 400
        Ascii.SceneView { id: scene; anchors.fill: parent; controller: scenes }
    }
    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            if (scenes.receivedFrames < 4 || root.capturing) return;
            if (root.software ? !scene.fallbackReady : !scene.animated) return;
            root.capturing = true;
            scene.grabToImage(result => {
                const saved = result.saveToFile(Quickshell.env("ASCII_RENDER_OUTPUT") + "/" + String(root.captures).padStart(3, "0") + ".png");
                if (!saved) Qt.exit(3);
                root.captures++;
                root.capturing = false;
                if (root.captures >= (root.software ? 1 : 120)) {
                    console.info("RENDER_CHECK", JSON.stringify({ frames: scenes.receivedFrames, animated: scene.animated,
                        fallback: scene.fallbackReady, error: scene.renderError, captures: root.captures }));
                    Qt.exit(root.software && scene.animated ? 4 : 0);
                }
            }, Qt.size(800, 400));
        }
    }
    Timer { interval: 15000; running: true; onTriggered: { console.error("Render timeout", scenes.lastError, scene.renderError); Qt.exit(2); } }
}
