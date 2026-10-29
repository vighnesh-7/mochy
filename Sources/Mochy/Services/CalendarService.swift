import AppKit
import EventKit
import Foundation
import SwiftUI

struct AgendaEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarName: String
    let color: Color
    let location: String?
    let joinURL: URL?

    var isHappeningNow: Bool { start <= Date() && end > Date() }
}

struct DueReminder: Identifiable, Equatable {
    let id: String
    let title: String
    let due: Date?
}

@MainActor
final class CalendarService: ObservableObject {
    enum Access { case unknown, granted, denied }

    @Published private(set) var today: [AgendaEvent] = []
    @Published private(set) var upcoming: [AgendaEvent] = []
    @Published private(set) var reminders: [DueReminder] = []
    @Published private(set) var eventAccess: Access = .unknown
    @Published private(set) var reminderAccess: Access = .unknown

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    private var dayObserver: NSObjectProtocol?

    func start() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess { eventAccess = .granted; refresh() }
        else if status == .denied || status == .restricted { eventAccess = .denied }
        let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
        if reminderStatus == .fullAccess { reminderAccess = .granted; refreshReminders() }
        else if reminderStatus == .denied || reminderStatus == .restricted { reminderAccess = .denied }
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        dayObserver = NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func requestAccess() {
        store.requestFullAccessToEvents { granted, _ in
            Task { @MainActor in
                self.eventAccess = granted ? .granted : .denied
                if granted { self.refresh() }
            }
        }
    }

    func requestReminderAccess() {
        store.requestFullAccessToReminders { granted, _ in
            Task { @MainActor in
                self.reminderAccess = granted ? .granted : .denied
                if granted { self.refreshReminders() }
            }
        }
    }

    func openPrivacySettings(reminders: Bool = false) {
        let pane = reminders ? "Privacy_Reminders" : "Privacy_Calendars"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    func refresh() {
        guard eventAccess == .granted else { return }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let horizon = calendar.date(byAdding: .hour, value: 36, to: Date()) ?? endOfDay
        let predicate = store.predicateForEvents(withStart: startOfDay, end: max(endOfDay, horizon), calendars: nil)
        let events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map(Self.agendaEvent)
        today = events.filter { $0.start < endOfDay && $0.end > startOfDay }
        upcoming = events.filter { !$0.isAllDay && $0.start > Date() }
        if reminderAccess == .granted { refreshReminders() }
    }

    func refreshReminders() {
        guard reminderAccess == .granted else { return }
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: end, calendars: nil)
        store.fetchReminders(matching: predicate) { items in
            let mapped = (items ?? []).prefix(30).map { item in
                DueReminder(id: item.calendarItemIdentifier, title: item.title ?? "Reminder", due: item.dueDateComponents?.date)
            }
            Task { @MainActor in self.reminders = mapped }
        }
    }

    func complete(_ reminder: DueReminder) {
        guard let item = store.calendarItem(withIdentifier: reminder.id) as? EKReminder else { return }
        item.isCompleted = true
        try? store.save(item, commit: true)
        reminders.removeAll { $0.id == reminder.id }
    }

    func open(_ event: AgendaEvent) {
        let seconds = Int(event.start.timeIntervalSinceReferenceDate)
        if let url = URL(string: "ical://ekevent/\(event.id)?method=show&options=more") , NSWorkspace.shared.open(url) { return }
        if let url = URL(string: "x-apple-calevent://\(seconds)") { NSWorkspace.shared.open(url) }
    }

    func openCalendarApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private static func agendaEvent(_ event: EKEvent) -> AgendaEvent {
        AgendaEvent(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? "Event",
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            calendarName: event.calendar.title,
            color: Color(cgColor: event.calendar.cgColor ?? CGColor(gray: 0.7, alpha: 1)),
            location: event.location,
            joinURL: joinURL(in: event)
        )
    }

    private static func joinURL(in event: EKEvent) -> URL? {
        let text = [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }.joined(separator: " ")
        let pattern = #"https?://[^\s<>"]*(zoom\.us|meet\.google\.com|teams\.microsoft\.com|teams\.live\.com|webex\.com|facetime\.apple\.com|whereby\.com|around\.co)[^\s<>"]*"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text)
        else { return nil }
        return URL(string: String(text[range]))
    }
}
