import AppKit
import SwiftUI

/// Renders island states to PNGs for design review. Not part of Mochy.app.
/// Usage: snapshot <output-directory>
@main
enum Snapshot {
    @MainActor
    static func main() {
        let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        _ = NSApplication.shared
        let model = AppModel()
        if let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main {
            model.notch = NotchGeometry.of(screen)
        }
        model.nowPlaying.start()
        model.battery.start()
        model.calendar.start()
        model.shelf.load()
        model.todo.load()
        RunLoop.main.run(until: Date().addingTimeInterval(3))

        func render(_ name: String) {
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
            let view = IslandRoot()
                .environmentObject(model)
                .frame(width: 900, height: 300)
                .background(Color(white: 0.82))
                .transaction { $0.disablesAnimations = true }
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
            try? png.write(to: out.appendingPathComponent("\(name).png"))
            print("wrote \(name).png")
        }

        render("1-idle")
        model.show(IslandAlert(symbol: "battery.100percent.bolt", tint: .green, title: "Charging · 82%", subtitle: "1 h 10 min until full · 96 W", duration: 60))
        render("2-alert")
        model.dismissAlert()
        for tab in [TabID.home, .shelf, .clipboard, .todo, .timer, .calendar] {
            model.expand(tab: tab)
            render("3-\(tab.rawValue)")
        }
        model.openPalette()
        render("4-palette")
        model.nowPlaying.stop()
    }
}
