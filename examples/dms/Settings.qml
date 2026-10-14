import QtQuick
import qs.Modules.Plugins

PluginSettings {
    pluginId: "asciiWallpaper"
    SliderSetting {
        settingKey: "speedPercent"
        label: "Animation speed"
        minimum: 25
        maximum: 200
        defaultValue: 100
        unit: "%"
    }
    SliderSetting {
        settingKey: "cycleMinutes"
        label: "Minutes per scene"
        minimum: 1
        maximum: 60
        defaultValue: 5
        unit: "min"
    }
    ToggleSetting { settingKey: "cycling"; label: "Cycle scenes"; defaultValue: true }
    ToggleSetting { settingKey: "paused"; label: "Pause animation"; defaultValue: false }
    ToggleSetting { settingKey: "syncWallpaper"; label: "Use scene still in DMS"; defaultValue: true }
}
