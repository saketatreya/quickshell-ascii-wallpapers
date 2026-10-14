import QtQuick
import Quickshell
import "AsciiWallpaper" as Ascii

ShellRoot {
    Ascii.Wallpaper {
        id: wallpaper
        controller: Ascii.Controller {
            scene: "night-coast"
            speed: 1
            fps: 15
            cycling: true
            cycleSeconds: 300
            // playlist: ["night-coast", "aurora-fjord", "tokyo-rain"]
        }
    }
    Ascii.Ipc { controller: wallpaper.controller }
}
