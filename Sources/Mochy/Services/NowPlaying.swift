import AppKit
import CoreImage
import Foundation
import SwiftUI

/// Reads the system media session (Music, Spotify, Chrome/Safari/YouTube tabs, Podcasts…)
/// through the MediaRemote bridge that runs inside /usr/bin/perl.
@MainActor
final class NowPlayingService: ObservableObject {
    @Published private(set) var title = ""
    @Published private(set) var artist = ""
    @Published private(set) var album = ""
    @Published private(set) var appName = ""
    @Published private(set) var bundleID = ""
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: Double = 0
    @Published private(set) var artwork: NSImage?
    @Published private(set) var accent: Color = .white
    @Published private(set) var lastChange = Date.distantPast
    @Published private(set) var bridgeError: String?

    var onTrackChange: ((String, String) -> Void)?

    private var elapsedAtStamp: Double = 0
    private var stamp = Date()
    private var rate: Double = 0
    private var artworkPath: String?
    private var process: Process?
    private var buffer = Data()
    private var restartDelay: TimeInterval = 1
    private var stopping = false

    var hasMedia: Bool { !title.isEmpty }

    var appIcon: NSImage? {
        guard !bundleID.isEmpty, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    func position(at date: Date = Date()) -> Double {
        let moving = isPlaying ? date.timeIntervalSince(stamp) * (rate > 0 ? rate : 1) : 0
        let value = elapsedAtStamp + moving
        return duration > 0 ? min(max(0, value), duration) : max(0, value)
    }

    // MARK: Bridge process

    private var resources: URL { Bundle.main.resourceURL ?? URL(fileURLWithPath: ".") }
    private var script: URL { resources.appendingPathComponent("mediaremote.pl") }
    private var library: URL { resources.appendingPathComponent("libMochyMediaRemote.dylib") }

    func start() {
        guard process == nil else { return }
        stopping = false
        guard FileManager.default.fileExists(atPath: library.path) else {
            bridgeError = "The media bridge is missing from the app bundle. Rebuild Mochy with build.sh."
            return
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        task.arguments = [script.path, library.path, "mochy_stream"]
        let output = Pipe()
        let input = Pipe()
        task.standardOutput = output
        task.standardInput = input
        task.standardError = FileHandle.nullDevice
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            Task { @MainActor in self?.consume(chunk) }
        }
        task.terminationHandler = { [weak self] _ in
            Task { @MainActor in self?.bridgeExited() }
        }
        do {
            try task.run()
            process = task
            bridgeError = nil
        } catch {
            bridgeError = "Couldn’t start the media bridge: \(error.localizedDescription)"
        }
    }

    func stop() {
        stopping = true
        process?.terminate()
        process = nil
    }

    private func bridgeExited() {
        process = nil
        guard !stopping else { return }
        let delay = restartDelay
        restartDelay = min(restartDelay * 2, 30)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.start() }
    }

    private func consume(_ chunk: Data) {
        buffer.append(chunk)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex ..< newline]
            buffer.removeSubrange(buffer.startIndex ... newline)
            guard let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            apply(json)
        }
        if buffer.count > 1 << 20 { buffer.removeAll() }
    }

    private func apply(_ json: [String: Any]) {
        restartDelay = 1
        if let error = json["error"] as? String {
            bridgeError = error
            return
        }
        let newTitle = (json["title"] as? String) ?? ""
        let newArtist = (json["artist"] as? String) ?? ""
        let changedTrack = newTitle != title || newArtist != artist
        title = newTitle
        artist = newArtist
        album = (json["album"] as? String) ?? ""
        appName = (json["app"] as? String) ?? ""
        bundleID = (json["bundle"] as? String) ?? ""
        isPlaying = (json["playing"] as? Bool) ?? false
        duration = (json["duration"] as? Double) ?? 0
        rate = (json["rate"] as? Double) ?? (isPlaying ? 1 : 0)
        elapsedAtStamp = (json["elapsed"] as? Double) ?? 0
        if let seconds = json["timestamp"] as? Double {
            stamp = Date(timeIntervalSince1970: seconds)
        }
        lastChange = Date()
        let path = json["artwork"] as? String
        if path != artworkPath {
            artworkPath = path
            loadArtwork(path)
        }
        if changedTrack, !newTitle.isEmpty {
            onTrackChange?(newTitle, newArtist)
        }
    }

    private func loadArtwork(_ path: String?) {
        guard let path, let image = NSImage(contentsOfFile: path) else {
            artwork = nil
            accent = .white
            return
        }
        artwork = image
        accent = Self.accent(of: image)
    }

    /// Average artwork color, lifted so it stays legible on the island's black.
    private static func accent(of image: NSImage) -> Color {
        guard let tiff = image.tiffRepresentation, let input = CIImage(data: tiff) else { return .white }
        let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: input, kCIInputExtentKey: CIVector(cgRect: input.extent)])
        guard let output = filter?.outputImage else { return .white }
        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        let color = NSColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        color.usingColorSpace(.deviceRGB)?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Color(hue: hue, saturation: min(saturation, 0.75), brightness: max(brightness, 0.78))
    }

    // MARK: Commands

    func playPause() {
        isPlaying.toggle()
        if !isPlaying { elapsedAtStamp = position(); stamp = Date() } else { stamp = Date() }
        send("2")
    }

    func next() { send("4") }
    func previous() { send("5") }

    func seek(to seconds: Double) {
        elapsedAtStamp = seconds
        stamp = Date()
        send("seek:\(seconds)")
    }

    func openSourceApp() {
        guard !bundleID.isEmpty, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func send(_ argument: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        task.arguments = [script.path, library.path, "mochy_send", argument]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
    }
}
