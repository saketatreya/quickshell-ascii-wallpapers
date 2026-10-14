import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string scene: "night-coast"
    property bool running: true
    property bool paused: false
    property bool cycling: true
    property real cycleSeconds: 300
    property real speed: 1
    property int fps: 15
    property var playlist: []
    property string nodeExecutable: "node"

    readonly property string currentScene: _currentScene || scene
    readonly property string sceneName: _metadata ? _metadata.name : currentScene.replace(/-/g, " ")
    readonly property var catalog: _catalog
    readonly property var frame: _frame
    readonly property bool healthy: _healthy
    readonly property string lastError: _error
    readonly property int receivedFrames: _receivedFrames
    readonly property url stillSource: Qt.resolvedUrl("assets/stills/" + (/^[a-z0-9-]+$/.test(currentScene) ? currentScene : "night-coast") + ".png")

    signal sceneSelected(string slug, url still)
    signal commandError(string message)

    property string _currentScene: ""
    property var _metadata: null
    property var _frame: null
    property var _catalog: []
    property bool _ready: false
    property bool _configured: false
    property bool _healthy: false
    property bool _destroying: false
    property string _error: ""
    property int _receivedFrames: 0
    property int _restarts: 0
    property double _lastPacket: Date.now()

    function _send(command) {
        if (!_ready || !worker.running) return false;
        worker.write(JSON.stringify(command) + "\n");
        return true;
    }
    function _configure() {
        const config = { command: "configure", fps: fps, speed: speed,
            cycling: cycling, cycleSeconds: cycleSeconds, paused: paused, playlist: playlist };
        // Do not send a stale scene when pause/speed follows next/select before
        // the worker has acknowledged it. Scene selection is its own command.
        if (!_configured) config.scene = currentScene;
        _send(config);
    }
    function choose(slug) {
        if (!_catalog.some(entry => entry.slug === slug)) return false;
        if (!_configured) {
            _currentScene = slug;
            _configure();
            return _ready;
        }
        return _send({ command: "scene", scene: slug });
    }
    function next() { return _send({ command: "next" }); }
    function previous() { return _send({ command: "previous" }); }
    function status() {
        return { scene: currentScene, scenes: catalog.length, cycling: cycling, cycleSeconds: cycleSeconds,
            speed: speed, fps: fps, paused: paused, running: running, healthy: healthy,
            frames: receivedFrames, error: lastError };
    }
    function _retry(message) {
        _healthy = false;
        _ready = false;
        _configured = false;
        if (message) _error = message;
        if (running && !_destroying && !retry.running) {
            _restarts++;
            retry.start();
        }
    }
    function restart() {
        _retry("Restarting scene worker");
        worker.running = false;
    }
    function _start() {
        _lastPacket = Date.now();
        worker.running = true;
    }

    onSceneChanged: {
        if (_ready) {
            if (scene !== currentScene && !choose(scene)) commandError("Unknown scene: " + scene);
        } else _currentScene = "";
    }
    onRunningChanged: {
        if (running) _start();
        else {
            retry.stop();
            _healthy = false;
            _ready = false;
            _configured = false;
            worker.running = false;
        }
    }
    onPausedChanged: reconfigure.restart()
    onCyclingChanged: reconfigure.restart()
    onCycleSecondsChanged: reconfigure.restart()
    onSpeedChanged: reconfigure.restart()
    onFpsChanged: reconfigure.restart()
    onPlaylistChanged: reconfigure.restart()
    onNodeExecutableChanged: { if (_ready) restart(); }
    Component.onCompleted: { if (running) _start(); }
    Component.onDestruction: { _destroying = true; worker.running = false; }

    Timer { id: reconfigure; interval: 0; onTriggered: root._configure() }
    Timer {
        id: retry
        interval: Math.min(30000, 500 * Math.pow(2, Math.min(root._restarts, 6)))
        onTriggered: { if (root.running) root._start(); }
    }
    Timer {
        interval: 2000
        running: root.running
        repeat: true
        onTriggered: {
            // Also catches a missing executable, which may not emit exited.
            if (!retry.running && Date.now() - root._lastPacket > 5000) {
                root._retry("Worker unavailable; check nodeExecutable and stderr");
                worker.running = false;
            }
        }
    }
    Process {
        id: worker
        command: [root.nodeExecutable, decodeURIComponent(Qt.resolvedUrl("runtime/worker.mjs").toString().replace(/^file:\/\//, ""))]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const packet = JSON.parse(data);
                    root._lastPacket = Date.now();
                    switch (packet.type) {
                    case "ready":
                        if (packet.protocol !== 1) { root._retry("Unsupported worker protocol"); worker.running = false; break; }
                        root._ready = true;
                        root._configured = false;
                        root._catalog = packet.catalog;
                        root._configure();
                        break;
                    case "scene":
                        root._metadata = packet;
                        root._currentScene = packet.slug;
                        root.sceneSelected(packet.slug, root.stillSource);
                        break;
                    case "frame":
                        if (!root._metadata || packet.revision !== root._metadata.revision) break;
                        // One object keeps the texture and its palette/geometry atomic.
                        root._frame = Object.assign({}, root._metadata, packet);
                        root._receivedFrames++;
                        root._configured = true;
                        root._healthy = true;
                        root._restarts = 0;
                        root._error = "";
                        break;
                    case "error":
                        root._retry(packet.message);
                        worker.running = false;
                        break;
                    case "command-error":
                        root._error = packet.message;
                        root.commandError(packet.message);
                        console.warn("ASCII wallpaper:", packet.message);
                        break;
                    }
                } catch (error) { console.warn("ASCII wallpaper packet:", error); }
            }
        }
        stderr: SplitParser { onRead: data => console.warn("ASCII wallpaper worker:", data) }
        onExited: (code, exitStatus) => {
            if (root.running) root._retry("Scene worker exited (" + code + ")");
        }
    }
}
