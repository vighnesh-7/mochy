import Foundation

struct TodoItem: Identifiable, Equatable, Codable {
    var id = UUID()
    var title: String
    var done = false
    var created = Date()
    var completed: Date?
}

@MainActor
final class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []
    var onAdded: (() -> Void)?
    var onCompleted: (() -> Void)?
    var onRemoved: (() -> Void)?
    var newestOnTop = true

    private var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mochy", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("todo.json")
    }

    var openCount: Int { items.filter { !$0.done }.count }

    var ordered: [TodoItem] {
        let open = items.filter { !$0.done }.sorted { newestOnTop ? $0.created > $1.created : $0.created < $1.created }
        let done = items.filter(\.done).sorted { ($0.completed ?? .distantPast) > ($1.completed ?? .distantPast) }
        return open + done
    }

    func load() {
        guard let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else { return }
        items = decoded.filter { !$0.done }
    }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = TodoItem(title: trimmed)
        if newestOnTop { items.insert(item, at: 0) } else { items.append(item) }
        save()
        onAdded?()
    }

    func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].done.toggle()
        items[index].completed = items[index].done ? Date() : nil
        if items[index].done { onCompleted?() }
        save()
    }

    /// Drops ticked items after the island closes, so they never sit around as “done”.
    func commitCompleted() {
        let remaining = items.filter { !$0.done }
        guard remaining.count != items.count else { return }
        items = remaining
        save()
    }

    func rename(_ item: TodoItem, to title: String) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { items.remove(at: index) } else { items[index].title = trimmed }
        save()
    }

    func delete(_ item: TodoItem) {
        let count = items.count
        items.removeAll { $0.id == item.id }
        guard items.count != count else { return }
        save()
        onRemoved?()
    }

    func clearCompleted() {
        let count = items.count
        items.removeAll(where: \.done)
        guard items.count != count else { return }
        save()
        onRemoved?()
    }

    /// An https link stored as a to-do, shown without the scheme when that option is on.
    enum Link {
        static func httpsURL(in title: String) -> URL? {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.lowercased().hasPrefix("https://"),
                  let url = URL(string: trimmed), url.host != nil else { return nil }
            return url
        }

        static func display(_ title: String, trimPrefix: Bool) -> String {
            guard trimPrefix, httpsURL(in: title) != nil else { return title }
            var text = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.lowercased().hasPrefix("https://") { text = String(text.dropFirst(8)) }
            if text.lowercased().hasPrefix("www.") { text = String(text.dropFirst(4)) }
            return text
        }

        static func opening(_ title: String, stripTrackers: Bool) -> URL? {
            let stored = stripTrackers ? ClipLink.withoutTrackers(title) : title
            return httpsURL(in: stored) ?? httpsURL(in: title)
        }
    }

    private func save() {
        let live = items.filter { !$0.done }
        if let data = try? JSONEncoder().encode(live) { try? data.write(to: url, options: .atomic) }
    }
}
