import Foundation

struct ActiveDownload: Identifiable, Equatable {
    let id: String
    var name: String
    /// nil when the browser doesn't say how big the file is.
    var fraction: Double?
    var bytes: Int64
}

/// Follows downloads in ~/Downloads. Browsers that publish file progress (Safari, Chrome)
/// report a fraction; for the rest Mochy watches the partial file grow.
@MainActor
final class DownloadMonitor: ObservableObject {
    @Published private(set) var active: [ActiveDownload] = []
    var onFinished: ((URL) -> Void)?

    private var subscriber: Any?
    private var published: [String: Progress] = [:]
    private var observations: [String: NSKeyValueObservation] = [:]
    private var partials: [String: Int64] = [:]
    private var timer: Timer?
    private let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    private static let partialExtensions = ["crdownload", "download", "part", "partial", "opdownload"]

    var primary: ActiveDownload? { active.first }

    func start() {
        subscriber = Progress.addSubscriber(forFileURL: folder) { [weak self] progress in
            let key = progress.fileURL?.path ?? UUID().uuidString
            Task { @MainActor in self?.track(progress, key: key) }
            return { [weak self] in
                Task { @MainActor in self?.untrack(key) }
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.scanPartials() }
        }
    }

    private func track(_ progress: Progress, key: String) {
        published[key] = progress
        observations[key] = progress.observe(\.fractionCompleted, options: [.initial]) { [weak self] _, _ in
            Task { @MainActor in self?.rebuild() }
        }
        rebuild()
    }

    private func untrack(_ key: String) {
        observations[key]?.invalidate()
        observations[key] = nil
        published[key] = nil
        rebuild()
        let finished = URL(fileURLWithPath: Self.stripPartial(key))
        if FileManager.default.fileExists(atPath: finished.path) { onFinished?(finished) }
    }

    private func scanPartials() {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        var seen: [String: Int64] = [:]
        for name in names where Self.partialExtensions.contains((name as NSString).pathExtension.lowercased()) {
            let path = folder.appendingPathComponent(name).path
            let size = Self.size(of: path)
            seen[path] = size
        }
        for (path, _) in partials where seen[path] == nil && published[path] == nil {
            let finished = URL(fileURLWithPath: Self.stripPartial(path))
            if FileManager.default.fileExists(atPath: finished.path) { onFinished?(finished) }
        }
        partials = seen
        rebuild()
    }

    private func rebuild() {
        var list: [ActiveDownload] = published.compactMap { key, progress in
            guard !progress.isFinished, !progress.isCancelled else { return nil }
            let fraction = progress.totalUnitCount > 0 ? progress.fractionCompleted : nil
            return ActiveDownload(id: key, name: Self.displayName(key), fraction: fraction, bytes: progress.completedUnitCount)
        }
        let covered = Set(list.map { Self.stripPartial($0.id) })
        for (path, size) in partials where !covered.contains(Self.stripPartial(path)) {
            list.append(ActiveDownload(id: path, name: Self.displayName(path), fraction: nil, bytes: size))
        }
        list.sort { $0.name < $1.name }
        if list != active { active = list }
    }

    private static func stripPartial(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        return partialExtensions.contains(ext) ? (path as NSString).deletingPathExtension : path
    }

    private static func displayName(_ path: String) -> String {
        (stripPartial(path) as NSString).lastPathComponent
    }

    private static func size(of path: String) -> Int64 {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return 0 }
        if !isDirectory.boolValue {
            return (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
        }
        let enumerator = FileManager.default.enumerator(atPath: path)
        var total: Int64 = 0
        while let file = enumerator?.nextObject() as? String {
            total += (try? FileManager.default.attributesOfItem(atPath: (path as NSString).appendingPathComponent(file))[.size] as? Int64) ?? 0
        }
        return total
    }
}
