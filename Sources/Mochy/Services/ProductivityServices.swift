import AppKit
import EventKit
import Foundation

@MainActor
final class CalendarService: ObservableObject {
    struct EventItem: Identifiable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let calendarName: String
        var joinURL: URL?
    }

    @Published var events: [EventItem] = []
    @Published var reminders: [EKReminder] = []
    @Published var status = "Calendar access is off"
    private let store = EKEventStore()

    func request() {
        store.requestFullAccessToEvents { granted, _ in
            Task { @MainActor in
                self.status = granted ? "Connected — calendar and tasks are syncing" : "Turn on Mochy in System Settings › Privacy & Security › Calendars"
                if granted { self.refresh() }
            }
        }
        store.requestFullAccessToReminders { granted, _ in
            Task { @MainActor in
                if granted { self.refreshReminders() }
            }
        }
    }

    func refresh() {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = store.events(matching: predicate).prefix(20).map { event in
            EventItem(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Event",
                start: event.startDate,
                end: event.endDate,
                calendarName: event.calendar.title,
                joinURL: Self.joinURL(in: event)
            )
        }
        refreshReminders()
    }

    func refreshReminders() {
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        store.fetchReminders(matching: predicate) { items in
            Task { @MainActor in
                self.reminders = (items ?? []).prefix(30).map { $0 }
            }
        }
    }

    func addReminder(_ title: String) {
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = store.defaultCalendarForNewReminders()
        try? store.save(reminder, commit: true)
        refreshReminders()
    }

    func toggle(_ reminder: EKReminder) {
        reminder.isCompleted.toggle()
        try? store.save(reminder, commit: true)
        refreshReminders()
    }

    var nextEvent: EventItem? { events.first }

    private static func joinURL(in event: EKEvent) -> URL? {
        let blob = ((event.notes ?? "") + " " + (event.url?.absoluteString ?? ""))
        let pattern = #"https?://[^\s]+(zoom|meet\.google|teams\.microsoft|facetime)[^\s]*"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: blob, range: NSRange(blob.startIndex..., in: blob)),
              let range = Range(match.range, in: blob)
        else { return event.url }
        return URL(string: String(blob[range]))
    }
}

@MainActor
final class TimerService: ObservableObject {
    enum Mode: String, CaseIterable { case timer, pomodoro, stopwatch }
    @Published var mode: Mode = .timer
    @Published var remaining: TimeInterval = 25 * 60
    @Published var elapsed: TimeInterval = 0
    @Published var running = false
    @Published var pomodoroPhase = "Focus"
    var onDone: ((String) -> Void)?
    var focusMinutes: Double = 25
    var breakMinutes: Double = 5
    private var started: Date?
    private var snapshot: TimeInterval = 25 * 60

    func setMinutes(_ minutes: Double) {
        remaining = minutes * 60
        snapshot = remaining
    }

    func toggle() {
        if running {
            running = false
            started = nil
        } else {
            running = true
            started = Date()
            if mode == .stopwatch { snapshot = elapsed }
            else { snapshot = remaining }
        }
    }

    func reset() {
        running = false
        started = nil
        elapsed = 0
        remaining = mode == .pomodoro ? focusMinutes * 60 : snapshot
        pomodoroPhase = "Focus"
    }

    func tick() {
        guard running, let started else { return }
        let delta = Date().timeIntervalSince(started)
        switch mode {
        case .stopwatch:
            elapsed = snapshot + delta
        case .timer, .pomodoro:
            remaining = max(0, snapshot - delta)
            if remaining == 0 {
                running = false
                if mode == .pomodoro {
                    if pomodoroPhase == "Focus" {
                        pomodoroPhase = "Break"
                        remaining = breakMinutes * 60
                        snapshot = remaining
                        running = true
                        self.started = Date()
                        onDone?("Focus done — take a break")
                    } else {
                        pomodoroPhase = "Focus"
                        remaining = focusMinutes * 60
                        snapshot = remaining
                        running = true
                        self.started = Date()
                        onDone?("Break over — back to focus")
                    }
                } else {
                    onDone?("Timer Done")
                }
            }
        }
    }
}

@MainActor
final class CalculatorService: ObservableObject {
    @Published var input = ""
    @Published var history: [String] = []
    var result: String {
        let expr = input.replacingOccurrences(of: "%", with: "*0.01")
        guard !expr.isEmpty else { return "" }
        let exprn = NSExpression(format: expr)
        if let value = exprn.expressionValue(with: nil, context: nil) as? NSNumber {
            return value.stringValue
        }
        return ""
    }

    func commit() {
        guard !result.isEmpty else { return }
        history.insert("\(input) = \(result)", at: 0)
        input = result
    }
}

@MainActor
final class NotesService: ObservableObject {
    @Published var draft = ""
    private var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mochy", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("scratchpad.txt")
    }

    func load() {
        draft = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    func save() {
        try? draft.write(to: url, atomically: true, encoding: .utf8)
    }

    func sendToAppleNotes() {
        save()
        let escaped = draft.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", """
        tell application "Notes"
            activate
            make new note at folder "Notes" with properties {name:"Mochy note", body:"\(escaped)"}
        end tell
        """]
        try? task.run()
    }
}

@MainActor
final class TranslateService: ObservableObject {
    @Published var source = "Hello"
    @Published var output = ""
    @Published var from = "en"
    @Published var to = "es"

    func run() {
        let encoded = source.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? source
        guard let url = URL(string: "https://api.mymemory.translated.net/get?q=\(encoded)&langpair=\(from)|\(to)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let response = json["responseData"] as? [String: Any],
                  let text = response["translatedText"] as? String
            else { return }
            Task { @MainActor in self.output = text }
        }.resume()
    }

    func swapLanguages() {
        Swift.swap(&from, &to)
        Swift.swap(&source, &output)
    }
}

@MainActor
final class ActivityService: ObservableObject {
    @Published var move: Double = 0.35
    @Published var type: Double = 0.2
    @Published var focus: Double = 0.15
    @Published var keystrokesToday = 0
    @Published var standReminders = true

    func keystroke() {
        keystrokesToday += 1
        type = min(1, type + 0.002)
    }
}

@MainActor
final class AIUsageService: ObservableObject {
    struct Row: Identifiable {
        let id = UUID()
        let name: String
        let detail: String
        let path: String
    }

    @Published var rows: [Row] = []

    func refresh() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates: [(String, URL)] = [
            ("Claude Code", home.appendingPathComponent(".claude")),
            ("Codex", home.appendingPathComponent(".codex")),
            ("Cursor", home.appendingPathComponent(".cursor")),
            ("Copilot", home.appendingPathComponent(".copilot")),
            ("Antigravity", home.appendingPathComponent(".gemini")),
        ]
        rows = candidates.compactMap { name, url in
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return Row(name: name, detail: "Local logs on this Mac", path: url.path)
        }
        if rows.isEmpty {
            rows = [Row(name: "No local CLIs found", detail: "Run a session in Claude Code, Codex, Cursor, Antigravity, or Copilot", path: "")]
        }
    }
}

@MainActor
final class AskAIService: ObservableObject {
    @Published var apiKey = ""
    @Published var prompt = ""
    @Published var reply = ""
    @Published var busy = false

    func send() {
        guard !apiKey.isEmpty else {
            reply = "Add an Anthropic API key in Settings → Ask AI."
            return
        }
        busy = true
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let body: [String: Any] = [
            "model": "claude-sonnet-4-5",
            "max_tokens": 512,
            "messages": [["role": "user", "content": prompt]],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, _, error in
            let text: String
            if let error {
                text = error.localizedDescription
            } else if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let content = json["content"] as? [[String: Any]],
                   let first = content.first?["text"] as? String
                {
                    text = first
                } else if let message = (json["error"] as? [String: Any])?["message"] as? String {
                    text = message
                } else {
                    text = String(data: data, encoding: .utf8) ?? "No reply"
                }
            } else {
                text = "No reply"
            }
            Task { @MainActor in
                self.reply = text
                self.busy = false
            }
        }.resume()
    }
}

@MainActor
final class StocksService: ObservableObject {
    struct Quote: Identifiable {
        let id: String
        var price: String
        var change: String
    }

    @Published var symbols: [String] = ["AAPL", "MSFT", "GOOG"]
    @Published var quotes: [Quote] = []

    func refresh() {
        quotes = symbols.map { Quote(id: $0, price: "—", change: "") }
        for symbol in symbols {
            guard let url = URL(string: "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(symbol)") else { continue }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let qr = json["quoteResponse"] as? [String: Any],
                      let result = (qr["result"] as? [[String: Any]])?.first
                else { return }
                let price = result["regularMarketPrice"] as? Double ?? 0
                let change = result["regularMarketChangePercent"] as? Double ?? 0
                Task { @MainActor in
                    if let idx = self.quotes.firstIndex(where: { $0.id == symbol }) {
                        self.quotes[idx].price = String(format: "%.2f", price)
                        self.quotes[idx].change = String(format: "%+.2f%%", change)
                    }
                }
            }.resume()
        }
    }
}

@MainActor
final class LauncherService: ObservableObject {
    struct AppItem: Identifiable {
        let id: URL
        let name: String
        let icon: NSImage
    }

    @Published var apps: [AppItem] = []
    @Published var query = ""

    func load() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Applications"),
            includingPropertiesForKeys: nil
        )) ?? []
        apps = urls.filter { $0.pathExtension == "app" }.map {
            AppItem(id: $0, name: $0.deletingPathExtension().lastPathComponent, icon: NSWorkspace.shared.icon(forFile: $0.path))
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var filtered: [AppItem] {
        guard !query.isEmpty else { return Array(apps.prefix(24)) }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(query) }.prefix(24).map { $0 }
    }

    func open(_ item: AppItem) {
        NSWorkspace.shared.open(item.id)
    }
}

@MainActor
final class TerminalService: ObservableObject {
    @Published var command = ""
    @Published var output = ""
    @Published var history: [String] = []

    func run() {
        let cmd = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        history.insert(cmd, at: 0)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lc", cmd]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        } catch {
            output = error.localizedDescription
        }
    }
}

@MainActor
final class PackagesService: ObservableObject {
    @Published var brewOutdated: [String] = []
    @Published var busy = false

    func refresh() {
        busy = true
        DispatchQueue.global().async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
            if !FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/brew") {
                task.executableURL = URL(fileURLWithPath: "/usr/local/bin/brew")
            }
            task.arguments = ["outdated", "--quiet"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            try? task.run()
            task.waitUntilExit()
            let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let rows = text.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            Task { @MainActor in
                self.brewOutdated = rows
                self.busy = false
            }
        }
    }
}

@MainActor
final class FocusService: ObservableObject {
    @Published var sessionActive = false
    @Published var minutes = 25
    @Published var startedAt: Date?

    func toggle() {
        sessionActive.toggle()
        startedAt = sessionActive ? Date() : nil
    }
}

@MainActor
final class NotificationInbox: ObservableObject {
    struct Banner: Identifiable {
        let id = UUID()
        let app: String
        let title: String
        let body: String
        let date = Date()
    }

    @Published var items: [Banner] = []

    func add(app: String, title: String, body: String) {
        items.insert(Banner(app: app, title: title, body: body), at: 0)
        items = Array(items.prefix(40))
    }
}

@MainActor
final class ShelfService: ObservableObject {
    @Published var files: [URL] = []
    private var folder: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mochy/Shelf", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func load() {
        files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
    }

    func add(_ url: URL) {
        let dest = folder.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.copyItem(at: url, to: dest)
        load()
    }
}
