import AppKit
import CoreText
import SwiftUI

/// Renders the island and settings panes for the README. Not part of Mochy.app.
@main
enum InterfaceShots {
    @MainActor
    static func main() {
        let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "docs/images")
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        _ = NSApplication.shared
        if let icon = NSImage(contentsOf: URL(fileURLWithPath: "Resources/Mochy.icns")) {
            NSApp.applicationIconImage = icon
        }
        let font = URL(fileURLWithPath: "Resources/Fonts/MacintoshSkeletalFilled.otf")
        CTFontManagerRegisterFontsForURL(font as CFURL, .process, nil)
        let model = AppModel()
        if let screen = NSScreen.main { model.notch = NotchGeometry.of(screen) }
        model.welcoming = false
        model.expand(tab: .home)
        model.prefs.homeCards = [.nowPlaying, .todo, .controls, .battery]

        func png<V: View>(_ name: String, _ view: V, size: CGSize) {
            let renderer = ImageRenderer(content: view.environmentObject(model).environment(\.colorScheme, .dark).frame(width: size.width, height: size.height))
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let data = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
            try? data.write(to: out.appendingPathComponent(name))
            print("wrote \(name)")
        }

        png("welcome.png", WelcomeIsland(shown: 6).background(Color.black), size: CGSize(width: 900, height: 260))
    }
}
