import Foundation

/// The system volume and brightness bezels live in OSDUIHelper. Killing it on a real change
/// lets that process relaunch without drawing the side HUD, because the island already shows it.
enum SystemHUD {
    static func hide() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["OSDUIHelper"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
    }
}
