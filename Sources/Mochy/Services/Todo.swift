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

    private var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mochy", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("todo.json")
    }

    var openCount: Int { items.filter { !$0.done }.count }

    var ordered: [TodoItem] {
        items.filter { !$0.done } + items.filter(\.done).sorted { ($0.completed ?? .distantPast) > ($1.completed ?? .distantPast) }
    }

    func load() {
        guard let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else { return }
        items = decoded
    }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.insert(TodoItem(title: trimmed), at: 0)
        save()
    }

    func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].done.toggle()
        items[index].completed = items[index].done ? Date() : nil
        save()
    }

    func rename(_ item: TodoItem, to title: String) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { items.remove(at: index) } else { items[index].title = trimmed }
        save()
    }

    func delete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearCompleted() {
        items.removeAll(where: \.done)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: url, options: .atomic) }
    }
}
