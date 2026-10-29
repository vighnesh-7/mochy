import AppKit
import Combine
import CoreGraphics
import Foundation
import SwiftUI
import Vision

@MainActor
final class CaptureTools: ObservableObject {
    @Published var lastQR = ""
    @Published var lastColor = ""
    @Published var lastOCR = ""
    @Published var recording = false

    func screenshot() {
        let dest = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mochy Screenshot \(Int(Date().timeIntervalSince1970)).png")
        run("/usr/sbin/screencapture", ["-i", dest.path])
    }

    func scrollingScreenshot() {
        let dest = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mochy Scroll \(Int(Date().timeIntervalSince1970)).png")
        run("/usr/sbin/screencapture", ["-i", "-T", "0", dest.path])
    }

    func recordScreen() {
        let dest = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mochy Recording \(Int(Date().timeIntervalSince1970)).mov")
        recording.toggle()
        if recording {
            run("/usr/sbin/screencapture", ["-v", dest.path], wait: false)
        }
    }

    func pickColor() {
        if #available(macOS 14.0, *) {
            NSColorSampler().show { color in
                guard let color else { return }
                Task { @MainActor in
                    let r = Int(color.redComponent * 255)
                    let g = Int(color.greenComponent * 255)
                    let b = Int(color.blueComponent * 255)
                    let hex = String(format: "#%02X%02X%02X", r, g, b)
                    self.lastColor = hex
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(hex, forType: .string)
                }
            }
        }
    }

    func scanQR(fullScreen: Bool = false) {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("mochy-qr.png")
        let args = fullScreen ? ["-x", temp.path] : ["-i", temp.path]
        run("/usr/sbin/screencapture", args)
        guard let image = NSImage(contentsOf: temp),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let cg = bitmap.cgImage
        else { return }
        let request = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try? handler.perform([request])
        if let payload = request.results?.compactMap(\.payloadStringValue).first {
            lastQR = payload
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(payload, forType: .string)
            if let url = URL(string: payload), url.scheme == "http" || url.scheme == "https" {
                NSWorkspace.shared.open(url)
            }
        }
        ocr(cg)
    }

    func ocr(_ cg: CGImage) {
        let request = VNRecognizeTextRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try? handler.perform([request])
        lastOCR = request.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n") ?? ""
        if !lastOCR.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(lastOCR, forType: .string)
        }
    }

    func pastePlain() {
        let pb = NSPasteboard.general
        let text = pb.string(forType: .string) ?? ""
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    func stripTrackers(_ urlString: String) -> String {
        guard var comps = URLComponents(string: urlString) else { return urlString }
        let banned = ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "fbclid", "gclid", "igshid"]
        comps.queryItems = comps.queryItems?.filter { !banned.contains($0.name.lowercased()) }
        return comps.string ?? urlString
    }

    func snapWindow(_ edge: String) {
        let script: String
        switch edge {
        case "left":
            script = """
            tell application "System Events" to tell (first process whose frontmost is true)
                set sz to size of window 1
                set pos to position of window 1
            end tell
            """
        default:
            script = ""
        }
        _ = script
        run("/usr/bin/osascript", ["-e", """
        tell application "System Events"
            tell (first process whose frontmost is true)
                set theScreen to {0, 0, 1512, 982}
                if "\(edge)" is "left" then
                    set position of window 1 to {0, 25}
                    set size of window 1 to {756, 940}
                else if "\(edge)" is "right" then
                    set position of window 1 to {756, 25}
                    set size of window 1 to {756, 940}
                else
                    set position of window 1 to {0, 25}
                    set size of window 1 to {1512, 940}
                end if
            end tell
        end tell
        """])
    }

    func switchSpace(_ dir: String) {
        let key = dir == "left" ? "123" : "124"
        run("/usr/bin/osascript", ["-e", """
        tell application "System Events" to key code \(key) using control down
        """])
    }

    private func run(_ path: String, _ args: [String], wait: Bool = true) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        try? task.run()
        if wait { task.waitUntilExit() }
    }
}

@MainActor
final class HUDController: ObservableObject {
    @Published var visible = false
    @Published var title = "Volume"
    @Published var value = 50
    @Published var symbol = "speaker.wave.2.fill"
    private var hideWork: DispatchWorkItem?

    func show(title: String, value: Int, symbol: String, duration: TimeInterval = 1.4) {
        self.title = title
        self.value = value
        self.symbol = symbol
        visible = true
        hideWork?.cancel()
        let work = DispatchWorkItem { self.visible = false }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }
}

@MainActor
final class KeycapHUD: ObservableObject {
    @Published var combo = ""
    @Published var visible = false
    private var hideWork: DispatchWorkItem?

    func show(_ text: String) {
        combo = text
        visible = true
        hideWork?.cancel()
        let work = DispatchWorkItem { self.visible = false }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }
}

@MainActor
final class LaunchAtLogin {
    static func set(_ on: Bool) {
        let bundled = Bundle.main.bundleIdentifier ?? "dev.mochy.app"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        if on {
            let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict>
            <key>Label</key><string>\(bundled)</string>
            <key>ProgramArguments</key><array>
            <string>/usr/bin/open</string><string>-a</string>
            <string>\(Bundle.main.bundlePath)</string>
            </array>
            <key>RunAtLoad</key><true/>
            </dict></plist>
            """
            let url = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents/\(bundled).plist")
            try? plist.write(to: url, atomically: true, encoding: .utf8)
            task.arguments = ["load", url.path]
        } else {
            let url = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents/\(bundled).plist")
            task.arguments = ["unload", url.path]
            try? FileManager.default.removeItem(at: url)
        }
        try? task.run()
    }
}
