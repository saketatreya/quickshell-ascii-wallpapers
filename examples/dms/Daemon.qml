import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Services
import "AsciiWallpaper" as Ascii

Item {
    id: root
    property var pluginService: null
    readonly property string pluginId: "asciiWallpaper"
    readonly property var config: SettingsData.getPluginSettingsForPlugin(pluginId)
    readonly property bool hidden: IdleService.isShellLocked || SessionService.lockedHint || IdleService.monitorsOff

    Ascii.Controller {
        id: player
        scene: root.config.scene || "night-coast"
        speed: Math.max(0.25, Math.min(2, (root.config.speedPercent ?? 100) / 100))
        cycleSeconds: Math.max(1, Math.min(60, root.config.cycleMinutes ?? 5)) * 60
        cycling: root.config.cycling ?? true
        paused: (root.config.paused ?? false) || root.hidden
        onSceneSelected: (slug, still) => {
            if (root.config.scene !== slug) PluginService.savePluginData(root.pluginId, "scene", slug);
            if (root.config.syncWallpaper ?? true) {
                SessionData.wallpaperPath = decodeURIComponent(still.toString().replace(/^file:\/\//, ""));
                SessionData.saveSettings();
            }
        }
    }
    Ascii.Wallpaper {
        controller: player
        screens: SettingsData.getFilteredScreens("wallpaper")
        layer: WlrLayer.Bottom
        visible: !root.hidden
        tintColor: Theme.surface
        tintAmount: 0.16
    }
    // Persist user controls in DMS, keeping the lock/monitor pause binding intact.
    IpcHandler {
        target: "asciiWallpaper"
        function status(): string { return JSON.stringify(player.status()); }
        function scenes(): string { return JSON.stringify(player.catalog); }
        function next(): string { return player.next() ? "ok" : "Worker is starting"; }
        function previous(): string { return player.previous() ? "ok" : "Worker is starting"; }
        function select(slug: string): string { return player.choose(slug) ? "ok" : "Unknown scene or worker unavailable"; }
        function pause(): string { PluginService.savePluginData(root.pluginId, "paused", true); return "ok"; }
        function resume(): string { PluginService.savePluginData(root.pluginId, "paused", false); return "ok"; }
        function pin(): string { PluginService.savePluginData(root.pluginId, "cycling", false); return "ok"; }
    }
}
