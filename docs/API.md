# Component API

Import the directory with `import "AsciiWallpaper" as Ascii`. No core component imports DMS services or contains machine-specific paths.

## Controller

Owns one worker. Share it across wallpaper surfaces and embedded views.

| Property | Default | Meaning |
| --- | --- | --- |
| `scene` | `"night-coast"` | Initial scene; changing the property selects another scene. |
| `running` | `true` | Start/stop the worker. Stopping leaves a static fallback. |
| `paused` | `false` | Freeze scene time and cycling; retain the current animated frame. |
| `cycling` | `true` | Advance through the playlist automatically. |
| `cycleSeconds` | `300` | Wall-clock seconds per scene, from 0.1 to 86400. Independent of speed. |
| `speed` | `1` | Animation time multiplier, from 0.1 to 4. |
| `fps` | `15` | Requested frames per second, from 1 to 30. |
| `playlist` | `[]` | Ordered unique scene slugs; empty means the complete catalog. |
| `nodeExecutable` | `"node"` | Command resolved through PATH, or an absolute Node executable path. |

`currentScene`, `sceneName`, `catalog`, `stillSource`, `healthy`, `lastError`, and `receivedFrames` are read-only status properties. `frame` is an atomic renderer packet; treat it as opaque in integrations.

Methods: `choose(slug)`, `next()`, `previous()`, `restart()`, `status()`. Selection/navigation return whether a command was queued, not whether it has rendered yet. `sceneSelected(slug, still)` fires after the worker selects a scene. `commandError(message)` reports rejected configuration.

The `scene` input is separate from `currentScene`: automatic cycling updates the latter without overwriting an external QML binding. Use `choose()` to select explicitly, including reselecting the original scene. A manual selection may lie outside the playlist; the next automatic advance rejoins it.

The controller retries failed workers with a delay that grows to 30 seconds. It also detects a worker that stops sending heartbeats. A stopped or failed worker leaves a bundled still available. A paused worker keeps its last frame and only emits a heartbeat once per second.

## Wallpaper

Creates one non-interactive layer-shell surface per screen.

| Property | Default |
| --- | --- |
| `controller` | A new `Controller` |
| `screens` | `Quickshell.screens` |
| `visible` | `true` |
| `layer` | `WlrLayer.Background` |
| `namespace` | `"ascii-wallpaper"` |
| `fillMode` | `Image.PreserveAspectFit` |
| `tintColor` | `"#1e1e2e"` |
| `tintAmount` | `0.16` |
| `transitionMs` | `50` |

Use `Image.PreserveAspectCrop` to fill the display and crop the 2:1 artwork. Fit keeps the entire scene with background margins. Cells always remain square. Filtering `screens` supports per-output placement; use separate controllers if outputs should display different scenes.

Hiding a wallpaper does not pause a controller shared with other views. Bind `paused` to your own visibility/idle policy. Input passes through the wallpaper, and it reserves no workspace area.

## SceneView

An ordinary Qt Quick `Item`. Give it a size and a `controller`. It supports the same `fillMode`, `tintColor`, `tintAmount`, and `transitionMs` options as `Wallpaper`.

Read-only `animated` indicates that a valid GPU frame is available; `fallbackReady` indicates the still image loaded. `renderError` contains shader or texture errors. GPU frames and static stills receive the same color overlay.

At startup, on worker failure, or with Qt Quick's software backend, the scene uses a bundled still. Double buffering keeps the current GPU texture untouched while a replacement loads. Slow rendering drops superseded pending frames instead of accumulating them. Very long transition durations reduce the visible update rate.

## Ipc

Optional adapter with a required `controller` and a `target` string (default `"asciiWallpaper"`). Exposes the commands in the README. Each instance in a shell needs a unique target.

The generic IPC adapter writes `paused`, `cycling`, `speed`, and `cycleSeconds`. Do not attach it directly to a controller whose corresponding properties are bound to a settings/lock service: assignments replace QML bindings. Use your shell's settings-aware handler, as demonstrated in the DMS adapter.
