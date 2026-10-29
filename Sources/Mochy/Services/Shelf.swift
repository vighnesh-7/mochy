import AppKit
import Foundation
import QuickLookThumbnailing

struct ShelfItem: Identifiable, Equatable {
    let id: String
    let url: URL
    let added: Date
    var name: String { url.lastPathComponent }
}

/// Files staged in the notch. Mochy keeps its own copy, so clearing the shelf never touches originals.
@MainActor
final class ShelfService: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []
    @Published private(set) var thumbnails: [String: NSImage] = [:]
    @Published private(set) var lastError: String?

    private var root: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mochy/Shelf", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func load() {
        let fm = FileManager.default
        let slots = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])) ?? []
        items = slots.compactMap { slot -> ShelfItem? in
            guard let file = (try? fm.contentsOfDirectory(at: slot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]))?.first else { return nil }
            let created = (try? slot.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return ShelfItem(id: slot.lastPathComponent, url: file, added: created)
        }
        .sorted { $0.added > $1.added }
        items.forEach(makeThumbnail)
    }

    @discardableResult
    func add(_ urls: [URL]) -> Int {
        var added = 0
        for url in urls where url.isFileURL {
            let slot = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: slot, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: url, to: slot.appendingPathComponent(url.lastPathComponent))
                added += 1
            } catch {
                try? FileManager.default.removeItem(at: slot)
                lastError = "Couldn’t add \(url.lastPathComponent): \(error.localizedDescription)"
            }
        }
        load()
        return added
    }

    func remove(_ item: ShelfItem) {
        try? FileManager.default.removeItem(at: item.url.deletingLastPathComponent())
        thumbnails[item.id] = nil
        load()
    }

    func clear() {
        items.forEach { try? FileManager.default.removeItem(at: $0.url.deletingLastPathComponent()) }
        thumbnails.removeAll()
        load()
    }

    func open(_ item: ShelfItem) { NSWorkspace.shared.open(item.url) }
    func reveal(_ item: ShelfItem) { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }

    var canAirDrop: Bool {
        NSSharingService(named: .sendViaAirDrop)?.canPerform(withItems: items.map(\.url)) ?? false
    }

    /// Opens the system AirDrop picker for the given files.
    func airDrop(_ urls: [URL], completion: ((Bool) -> Void)? = nil) {
        guard !urls.isEmpty, let service = NSSharingService(named: .sendViaAirDrop) else {
            lastError = "AirDrop isn’t available on this Mac."
            completion?(false)
            return
        }
        guard service.canPerform(withItems: urls) else {
            lastError = "Turn on Wi-Fi and Bluetooth to use AirDrop."
            completion?(false)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: urls)
        completion?(true)
    }

    private func makeThumbnail(_ item: ShelfItem) {
        guard thumbnails[item.id] == nil else { return }
        thumbnails[item.id] = NSWorkspace.shared.icon(forFile: item.url.path)
        let request = QLThumbnailGenerator.Request(fileAt: item.url, size: CGSize(width: 96, height: 96), scale: NSScreen.main?.backingScaleFactor ?? 2, representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            guard let image = representation?.nsImage else { return }
            Task { @MainActor in self?.thumbnails[item.id] = image }
        }
    }
}

/// Watches the screenshot folder so new captures can land on the shelf.
@MainActor
final class ScreenshotWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var known = Set<String>()
    var onScreenshot: ((URL) -> Void)?

    var folder: URL {
        let configured = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
        if let configured, !configured.isEmpty {
            return URL(fileURLWithPath: (configured as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }

    func start() {
        stop()
        known = Set(listing())
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in Task { @MainActor in self?.scan() } }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func listing() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
    }

    private func scan() {
        let now = listing()
        for name in now where !known.contains(name) && !name.hasPrefix(".") {
            let lower = name.lowercased()
            guard lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".heic") || lower.hasSuffix(".mov") else { continue }
            guard lower.hasPrefix("screenshot") || lower.hasPrefix("screen shot") || lower.hasPrefix("screen recording") else { continue }
            onScreenshot?(folder.appendingPathComponent(name))
        }
        known = Set(now)
    }
}
