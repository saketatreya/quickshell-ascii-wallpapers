# Dank Material Shell adapter

The core module works without DMS. `examples/dms/` provides a small daemon plugin adapter for DMS 1.6, using the service interfaces present in 1.6.3.

From the cloned repository, copy the adapter and module into a **new** plugin directory:

```sh
plugin_dir="${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugins/asciiWallpaper"
mkdir "$plugin_dir"
cp examples/dms/Daemon.qml examples/dms/Settings.qml examples/dms/plugin.json "$plugin_dir/"
cp -R AsciiWallpaper "$plugin_dir/"
```

If that directory already exists, update your existing installation deliberately. These commands do not replace another wallpaper plugin. Disable any other animated wallpaper plugin before enabling **ASCII Wallpapers** in DMS settings.

The adapter uses DMS's filtered wallpaper screen list and the bottom layer. It pauses during shell lock, a logind locked hint, or display-off, and hides its surfaces while locked. Speed, cycle interval, cycling, and pause are available in its plugin settings. The selected scene persists in DMS's plugin data.

By default it also assigns the current scene's bundled still to `SessionData.wallpaperPath`, so DMS surfaces that read that wallpaper can use it. Turn off **Use scene still in DMS** if you want to keep another DMS wallpaper. An external locker with its own image path needs a separate integration with `sceneSelected`; this module does not configure a locker or greeter.

```sh
dms ipc call asciiWallpaper next
dms ipc call asciiWallpaper select tokyo-rain
dms ipc call asciiWallpaper pin
dms ipc call asciiWallpaper pause
dms ipc call asciiWallpaper resume
dms ipc call asciiWallpaper status
```

The adapter routes controls through `PluginService` so a manual pause/resume never removes the automatic lock pause binding. Adjust its theme tint, add a scene picker, or register the controller in your own plugin UI as needed.

Keep this plugin inside DMS's process. Do not run a second DMS instance to host the wallpaper. For development, test the standalone `preview.qml` first, then reload the plugin; changes to imported QML types or shaders may require restarting your existing DMS service.
