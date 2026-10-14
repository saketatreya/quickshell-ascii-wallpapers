import QtQuick
import Quickshell
import "../AsciiWallpaper" as Ascii

ShellRoot {
    id: root
    property int phase: 0
    property double entered: Date.now()
    property int frames: 0
    Ascii.Controller { id: scenes; cycling: false }
    function advance() { phase++; entered = Date.now(); }
    function fail(message) { console.error("CONTROLLER_CHECK", message, JSON.stringify(scenes.status())); Qt.exit(1); }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            const elapsed = Date.now() - root.entered;
            switch (root.phase) {
            case 0:
                if (scenes.receivedFrames < 2) break;
                scenes.choose("aurora-fjord");
                scenes.paused = true; // Regression: configure must not revert a pending selection.
                root.advance();
                break;
            case 1:
                if (elapsed < 500) break;
                if (scenes.currentScene !== "aurora-fjord") { root.fail("Selection was reverted by pause"); break; }
                root.frames = scenes.receivedFrames;
                root.advance();
                break;
            case 2:
                if (elapsed < 500) break;
                if (scenes.receivedFrames !== root.frames) { root.fail("Pause kept rendering"); break; }
                scenes.restart();
                root.advance();
                break;
            case 3:
                if (!scenes.healthy || scenes.receivedFrames <= root.frames) break;
                if (scenes.currentScene !== "aurora-fjord" || !scenes.paused) { root.fail("Restart lost state"); break; }
                scenes.running = false;
                root.advance();
                break;
            case 4:
                if (elapsed < 200) break;
                if (scenes.healthy) { root.fail("Stopped controller is healthy"); break; }
                scenes.running = true;
                root.advance();
                break;
            case 5:
                if (!scenes.healthy) break;
                console.info("CONTROLLER_CHECK passed: selection/pause race, pause, restart, stop/start");
                Qt.exit(0);
            }
        }
    }
    Timer { interval: 12000; running: true; onTriggered: root.fail("Timed out"); }
}
