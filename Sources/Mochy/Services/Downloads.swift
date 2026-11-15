import AppKit
import Foundation

struct ActiveDownload: Identifiable, Equatable {
    enum Kind: Equatable { case download, airdrop, transfer, usb }

    let id: String
    var name: String
    /// nil when the sender doesn't say how big the file is.
    var fraction: Double?
    var bytes: Int64
    var kind: Kind
}

/// Follows browser downloads, AirDrop receives, and other file transfers into Downloads and Desktop.
@MainActor
final class DownloadMonitor: ObservableObject {
    @Published private(set) var active: [ActiveDownload] = []
    var onFinished: ((URL) -> Void)?

    private var subscribers: [Any] = []
    private var published: [String: Progress] = [:]
    private var partials: [String: Int64] = [:]
    private var regularSizes: [String: Int64] = [:]
    /// Files seen for the first time; announced only after their size stops changing.
    private var fresh: [String: Int64] = [:]
    private var growing: Set<String> = []
    private var announced: Set<String> = []
    private var seeded = false
    private var timer: Timer?
    private var volumeSubscribers: [String: Any] = [:]
    private var usbRoots: [String] = []
    private let folders = [
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0],
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0],
    ]
    private static let partialExtensions = ["crdownload", "download", "part", "partial", "opdownload"]

    var primary: ActiveDownload? { active.max { ($0.fraction ?? 0) < ($1.fraction ?? 0) } ?? active.first }

    func start() {
        guard subscribers.isEmpty else { return }
        for folder in folders {
            let token = Progress.addSubscriber(forFileURL: folder) { [weak self] progress in
                let key = progress.fileURL?.path ?? UUID().uuidString
                Task { @MainActor in self?.track(progress, key: key) }
                return { [weak self] in
                    Task { @MainActor in self?.untrack(key) }
                }
            }
            subscribers.append(token)
        }
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshVolumes() }
        }
        workspace.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshVolumes() }
        }
        refreshVolumes()
        poll()
    }

    private func refreshVolumes() {
        let keys: Set<URLResourceKey> = [.volumeIsRemovableKey, .volumeIsEjectableKey, .volumeIsInternalKey]
        let mounted = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: Array(keys), options: [.skipHiddenVolumes]) ?? []
        var roots: [String] = []
        for url in mounted {
            let values = try? url.resourceValues(forKeys: keys)
            let external = values?.volumeIsInternal == false && (values?.volumeIsRemovable == true || values?.volumeIsEjectable == true)
            guard external else { continue }
            roots.append(url.path)
            guard volumeSubscribers[url.path] == nil else { continue }
            let token = Progress.addSubscriber(forFileURL: url) { [weak self] progress in
                let key = progress.fileURL?.path ?? UUID().uuidString
                Task { @MainActor in self?.track(progress, key: key) }
                return { [weak self] in
                    Task { @MainActor in self?.untrack(key) }
                }
            }
            volumeSubscribers[url.path] = token
        }
        usbRoots = roots
    }

    private func track(_ progress: Progress, key: String) {
        published[key] = progress
        rebuild()
    }

    private func untrack(_ key: String) {
        let progress = published[key]
        published[key] = nil
        if let url = progress?.fileURL {
            let finished = URL(fileURLWithPath: Self.stripPartial(url.path))
            if FileManager.default.fileExists(atPath: finished.path) { finish(finished) }
        } else {
            let finished = URL(fileURLWithPath: Self.stripPartial(key))
            if FileManager.default.fileExists(atPath: finished.path) { finish(finished) }
        }
        rebuild()
    }

    private func poll() {
        var seenPartials: [String: Int64] = [:]
        var seenRegular: [String: Int64] = [:]
        for folder in folders {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            for name in names where !name.hasPrefix(".") && name != ".DS_Store" && name != ".localized" {
                let url = folder.appendingPathComponent(name)
                let path = url.path
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else { continue }
                let size = Self.size(of: path)
                if Self.partialExtensions.contains(url.pathExtension.lowercased()) {
                    seenPartials[path] = size
                } else {
                    seenRegular[path] = size
                }
            }
        }
        if !seeded {
            regularSizes = seenRegular
            partials = seenPartials
            seeded = true
            rebuild()
            return
        }
        for (path, _) in partials where seenPartials[path] == nil && published[path] == nil {
            let finished = URL(fileURLWithPath: Self.stripPartial(path))
            if FileManager.default.fileExists(atPath: finished.path) {
                fresh.removeValue(forKey: finished.path)
                growing.remove(finished.path)
                finish(finished)
            }
        }
        var nextFresh: [String: Int64] = [:]
        var nextGrowing = Set<String>()
        let downloadsRoot = folders[0].path
        for (path, size) in seenRegular where path.hasPrefix(downloadsRoot) && !announced.contains(path) {
            if growing.contains(path) {
                if let previous = regularSizes[path], size > previous {
                    nextGrowing.insert(path)
                } else {
                    finish(URL(fileURLWithPath: path))
                }
            } else if let firstSize = fresh[path] {
                if size > firstSize {
                    nextGrowing.insert(path)
                } else {
                    finish(URL(fileURLWithPath: path))
                }
            } else if regularSizes[path] == nil {
                nextFresh[path] = size
            } else if let previous = regularSizes[path], size > previous {
                nextGrowing.insert(path)
            }
        }
        fresh = nextFresh
        growing = nextGrowing
        partials = seenPartials
        regularSizes = seenRegular
        rebuild()
    }

    private func finish(_ url: URL) {
        let path = url.path
        guard !Self.partialExtensions.contains(url.pathExtension.lowercased()) else { return }
        guard announced.insert(path).inserted else { return }
        guard FileManager.default.fileExists(atPath: path) else {
            announced.remove(path)
            return
        }
        onFinished?(url)
    }

    private func rebuild() {
        var list: [ActiveDownload] = published.compactMap { key, progress in
            guard !progress.isFinished, !progress.isCancelled else { return nil }
            let fraction = progress.totalUnitCount > 0 ? progress.fractionCompleted : nil
            let bytes = max(progress.completedUnitCount, Self.size(of: progress.fileURL?.path ?? key))
            let shown = (fraction ?? 0) < 0.005 && bytes > 0 ? nil : fraction
            return ActiveDownload(
                id: key,
                name: Self.displayName(key),
                fraction: shown,
                bytes: bytes,
                kind: Self.kind(of: progress, path: key, usbRoots: usbRoots)
            )
        }
        let covered = Set(list.map { Self.stripPartial($0.id) })
        for (path, size) in partials where !covered.contains(Self.stripPartial(path)) && !covered.contains(path) {
            list.append(ActiveDownload(id: path, name: Self.displayName(path), fraction: nil, bytes: size, kind: .download))
        }
        for path in growing {
            guard seenGrowing(path, covered: covered, list: list), let size = regularSizes[path] else { continue }
            list.append(ActiveDownload(id: path, name: Self.displayName(path), fraction: nil, bytes: size, kind: .airdrop))
        }
        list.sort { $0.name < $1.name }
        if list != active { active = list }
    }

    private func seenGrowing(_ path: String, covered: Set<String>, list: [ActiveDownload]) -> Bool {
        !covered.contains(path) && !list.contains { $0.id == path }
    }

    private static func kind(of progress: Progress, path: String, usbRoots: [String]) -> ActiveDownload.Kind {
        let text = [progress.localizedDescription, progress.localizedAdditionalDescription]
            .compactMap { $0 }
            .joined(separator: " ")
        if text.localizedCaseInsensitiveContains("airdrop") { return .airdrop }
        if progress.fileOperationKind == .downloading || progress.fileOperationKind == .decompressingAfterDownloading {
            return .download
        }
        if path.contains("/Downloads/") { return .download }
        if usbRoots.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) { return .usb }
        return .transfer
    }

    private static func stripPartial(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        return partialExtensions.contains(ext) ? (path as NSString).deletingPathExtension : path
    }

    private static func displayName(_ path: String) -> String {
        (stripPartial(path) as NSString).lastPathComponent
    }

    private static func size(of path: String) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
    }
}
