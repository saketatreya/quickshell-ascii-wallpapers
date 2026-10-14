import Quickshell
import Quickshell.Io

Scope {
    id: root
    required property Controller controller
    property string target: "asciiWallpaper"
    IpcHandler {
        target: root.target
        function status(): string { return JSON.stringify(root.controller.status()); }
        function scenes(): string { return JSON.stringify(root.controller.catalog); }
        function next(): string { return root.controller.next() ? "ok" : "Worker is starting"; }
        function previous(): string { return root.controller.previous() ? "ok" : "Worker is starting"; }
        function select(scene: string): string { return root.controller.choose(scene) ? "ok" : "Unknown scene or worker unavailable"; }
        function pause(): string { root.controller.paused = true; return "ok"; }
        function resume(): string { root.controller.paused = false; return "ok"; }
        function speed(multiplier: string): string {
            const value = Number(multiplier);
            if (!Number.isFinite(value) || value < 0.1 || value > 4) return "Choose a speed from 0.1 to 4";
            root.controller.speed = value;
            return "ok";
        }
        function cycle(seconds: string): string {
            const value = Number(seconds);
            if (!Number.isFinite(value) || value < 0.1 || value > 86400) return "Choose 0.1–86400 seconds";
            root.controller.cycleSeconds = value;
            root.controller.cycling = true;
            return "ok";
        }
        function pin(): string { root.controller.cycling = false; return "ok"; }
    }
}
