# Development

The runtime has no npm dependencies. Node 22+ is the supported baseline. GitHub Actions tests the worker on Node 22 and 24; GPU and compositor behavior are checked locally.

## Rendering and failure checks

```sh
npm test
qs -p verify-controller.qml
mkdir -p test-output/gpu
ASCII_RENDER_OUTPUT="$PWD/test-output/gpu" qs -p verify.qml
python3 tests/check-render.py test-output/gpu

mkdir -p test-output/software
QT_QUICK_BACKEND=software ASCII_TEST_SOFTWARE=1 \
  ASCII_RENDER_OUTPUT="$PWD/test-output/software" qs -p verify.qml
python3 tests/check-render.py test-output/software
```

Run the GPU check in an actual graphical session. Offscreen Qt generally selects the software backend, so it cannot establish that the shader works. The software check expects a visible still and `animated: false`.

The GPU check samples 120 frames from a fixed scene, looking for blank textures and sudden brightness drops. The controller check covers a rapid select/pause sequence, frozen playback, restart state, and stop/start. Worker tests decode every scene's PNG grids, exercise all-scene cycling, playlists, rejected configuration, stdin shutdown, and stdout backpressure.

## Architecture

`Controller.qml` manages a persistent Node process, settings, scene metadata, health, and restart delays. `runtime/engine.mjs` runs the vendored scene algorithms. It produces a 200×100 RGBA PNG where red stores the glyph index and green stores the palette index. A separate 64×1 PNG carries the scene palette.

`SceneView.qml` provides sizing, still fallback, and tint. `internal/SceneTexture.qml` maintains two texture slots, uploads only into the inactive slot, and blends between them using the bundled Qt shader. Metadata and grids are delivered together to the renderer so scene changes cannot accidentally use another scene's palette. Only the latest pending frame is retained.

`Wallpaper.qml` handles layer-shell placement and screen lifecycle. `Ipc.qml` is optional. Neither the renderer nor the worker knows about DMS, compositor configuration, desktop clocks, locks, or user settings files.

## Worker protocol

The process reads newline-delimited JSON from stdin and writes it to stdout. Diagnostics belong on stderr. It emits `{ "type": "ready", "protocol": 1, "catalog": [...] }`, then waits for `configure`.

```json
{"command":"configure","scene":"night-coast","fps":15,"speed":1,"cycling":true,"cycleSeconds":300,"paused":false,"playlist":[]}
```

Further commands are `configure` (partial update), `scene` (with `scene`), `next`, `previous`, `pause`, and `resume`. Commands may include a `requestId`, echoed in their `state` or `command-error` response. Invalid configuration is rejected before mutating state.

Events: `scene` (palette and dimensions), `frame` (indexed PNG and matching revision), `state`, `heartbeat`, `command-error`, and fatal `error`. Consumers should pair a frame with metadata of the same revision. Closing stdin stops the worker. Production pauses when stdout is backpressured; scene time does not advance while the consumer is blocked.

## Rebuilding assets

The checked-in assets are sufficient to run the module. Rebuilding is only needed when changing scene sources, glyphs, or the shader.

The shader is serialized with Qt's 6.5 compatibility format, so a newer local Shader Baker does not raise the runtime's Qt 6.8 minimum.

```sh
# Qt Shader Tools, with qsb on PATH:
sh scripts/build-shader.sh
# Or set QSB to your distribution's Qt 6 qsb path.

# Python 3 + Pillow, Node.js on PATH:
python3 scripts/build-assets.py
```

The fallback builder uses the same glyph atlas and scene data as the shader. It renders time 3 into 2000×1000 PNGs with original scene colors; runtime tint is applied by QML. No desktop screenshots or user files are included in generated assets.

To refresh the upstream scene snapshot, provide a local checkout of [bas3line/ascii](https://github.com/bas3line/ascii):

```sh
node scripts/import-scenes.mjs /path/to/ascii
python3 scripts/build-assets.py
npm test
```

The importer requires Node's `stripTypeScriptTypes` API (22.13+), records the exact upstream commit, and retains its MIT license. Review upstream changes before importing. The current renderer contract is a 200×100 square-cell grid, glyphs ` ·•●`, and at most 64 RGB palette colors; new scene formats require renderer changes.
