import AppKit
import Carbon.HIToolbox
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, island, activities, shortcuts
    case home, tabs
    case nowPlaying, calendar, shelf, clipboard, pomodoro, caffeine
    case developer, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .island: "Island"
        case .activities: "Live Activities"
        case .shortcuts: "Keyboard Shortcuts"
        case .home: "Home Layout"
        case .tabs: "Tabs"
        case .nowPlaying: "Now Playing"
        case .calendar: "Calendar & Reminders"
        case .shelf: "Shelf"
        case .clipboard: "Clipboard"
        case .pomodoro: "Pomodoro"
        case .caffeine: "Caffeine"
        case .developer: "Developer"
        case .about: "About Mochy"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .island: "capsule.fill"
        case .activities: "bell.badge.fill"
        case .shortcuts: "command"
        case .home: "square.grid.2x2.fill"
        case .tabs: "rectangle.3.group.fill"
        case .nowPlaying: "play.fill"
        case .calendar: "calendar"
        case .shelf: "tray.full.fill"
        case .clipboard: "doc.on.clipboard.fill"
        case .pomodoro: "timer"
        case .caffeine: "cup.and.saucer.fill"
        case .developer: "chevron.left.forwardslash.chevron.right"
        case .about: "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .general, .about: .gray
        case .island: .black
        case .activities: .red
        case .shortcuts: .indigo
        case .home: .blue
        case .tabs: .cyan
        case .nowPlaying: .pink
        case .calendar: .red
        case .shelf: .teal
        case .clipboard: .purple
        case .pomodoro: .orange
        case .caffeine: .brown
        case .developer: .green
        }
    }

    static let groups: [[SettingsPane]] = [
        [.general, .island, .activities, .shortcuts],
        [.home, .tabs],
        [.nowPlaying, .calendar, .shelf, .clipboard, .pomodoro, .caffeine],
        [.developer, .about],
    ]
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var pane: SettingsPane? = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $pane) {
                ForEach(Array(SettingsPane.groups.enumerated()), id: \.offset) { _, group in
                    Section {
                        ForEach(group) { item in
                            Label {
                                Text(item.title)
                            } icon: {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(item.color.gradient))
                            }
                            .tag(item)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            PaneContent(pane: pane ?? .general)
                .id(pane)
                .navigationTitle((pane ?? .general).title)
        }
        .frame(minWidth: 760, minHeight: 540)
    }
}

private struct PaneContent: View {
    @EnvironmentObject var model: AppModel
    let pane: SettingsPane

    var body: some View {
        Group {
            switch pane {
            case .general: GeneralPane(calendar: model.calendar)
            case .island: IslandPane()
            case .activities: ActivitiesPane()
            case .shortcuts: ShortcutsPane()
            case .home: HomeLayoutPane()
            case .tabs: TabsPane()
            case .nowPlaying: NowPlayingPane(media: model.nowPlaying)
            case .calendar: CalendarPane(calendar: model.calendar)
            case .shelf: ShelfPane(shelf: model.shelf)
            case .clipboard: ClipboardPane(clipboard: model.clipboard)
            case .pomodoro: PomodoroPane()
            case .caffeine: CaffeinePane(caffeine: model.caffeine)
            case .developer: DeveloperPane()
            case .about: AboutPane()
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: Panes

private struct GeneralPane: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var calendar: CalendarService

    var body: some View {
        Form {
            Section {
                Toggle("Open at Login", isOn: $model.prefs.launchAtLogin)
                Toggle("Show Menu Bar Icon", isOn: $model.prefs.showMenuBarIcon)
                Toggle("Follow the Pointer to Other Displays", isOn: $model.prefs.followPointerDisplay)
            } footer: {
                Text("Without the menu bar icon, open Settings with \(model.prefs.shortcuts[.settings]?.display ?? "the Settings shortcut") or by opening Mochy again from Applications.")
            }
            Section("Permissions") {
                AccessRow(title: "Calendar", detail: "Today’s events and meeting alerts", access: calendar.eventAccess, request: calendar.requestAccess, settings: { calendar.openPrivacySettings() })
                AccessRow(title: "Reminders", detail: "Reminders due today in To-Do", access: calendar.reminderAccess, request: calendar.requestReminderAccess, settings: { calendar.openPrivacySettings(reminders: true) })
            }
        }
    }
}

private struct AccessRow: View {
    let title: String
    let detail: String
    let access: CalendarService.Access
    let request: () -> Void
    let settings: () -> Void

    var body: some View {
        LabeledContent {
            switch access {
            case .granted: Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .unknown: Button("Allow…", action: request)
            case .denied: Button("Open Privacy Settings…", action: settings)
            }
        } label: {
            Text(title)
            Text(detail)
        }
    }
}

private struct IslandPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section("Opening and Closing") {
                Toggle("Open on Hover", isOn: $model.prefs.openOnHover)
                SecondsSlider(title: "Hover Delay", value: $model.prefs.hoverDelay, range: 0 ... 1, step: 0.05)
                    .disabled(!model.prefs.openOnHover)
                Toggle("Close When the Pointer Leaves", isOn: $model.prefs.closeOnMouseExit)
                SecondsSlider(title: "Close Delay", value: $model.prefs.closeDelay, range: 0 ... 2, step: 0.1)
                    .disabled(!model.prefs.closeOnMouseExit)
                Toggle("Haptic Feedback on Open", isOn: $model.prefs.hapticFeedback)
            }
            Section {
                Picker("Size", selection: $model.prefs.panelSize) {
                    ForEach(PanelSize.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Reopen on the Last Tab", isOn: $model.prefs.rememberLastTab)
            } header: {
                Text("Layout")
            } footer: {
                Text("Pin the island from its header to keep it open while you work.")
            }
        }
    }
}

private struct ActivitiesPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Now Playing", isOn: $model.prefs.mediaActivity)
                Toggle("Timers", isOn: $model.prefs.timerActivity)
                Toggle("Download Progress", isOn: $model.prefs.downloadActivity)
                Toggle("Caffeine", isOn: $model.prefs.caffeineActivity)
                Toggle("Volume Changes", isOn: $model.prefs.volumeActivity)
            } header: {
                Text("Beside the Notch")
            } footer: {
                Text("When several are active, Mochy shows the most time-sensitive one.")
            }
            Section("Alerts") {
                Toggle("New Track", isOn: $model.prefs.trackChangePeek)
                Toggle("Charging and Unplugging", isOn: $model.prefs.chargingAlerts)
                Toggle("Low Battery at 20%, 10% and 5%", isOn: $model.prefs.lowBatteryAlert)
                Toggle("Upcoming Events", isOn: $model.prefs.eventAlerts)
                Stepper(value: $model.prefs.eventAlertMinutes, in: 1 ... 30) {
                    LabeledContent("Alert Before an Event", value: "\(model.prefs.eventAlertMinutes) min")
                }
                .disabled(!model.prefs.eventAlerts)
            }
            Section {
                Button("Preview an Alert") {
                    model.show(IslandAlert(symbol: "sparkles", tint: .white, title: "This Is an Alert", subtitle: "Alerts drop out of the notch and fade away", duration: 4))
                }
            }
        }
    }
}

private struct ShortcutsPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section {
                ForEach(ShortcutID.allCases) { id in
                    LabeledContent(id.title) { ShortcutRecorder(id: id) }
                }
            } footer: {
                Text("Shortcuts work in any app and don’t need Accessibility access. Click one to change it; press Delete to remove it or Esc to cancel.")
            }
            if !model.shortcutFailures.isEmpty {
                Section {
                    Label("Another app already uses: \(model.shortcutFailures.joined(separator: ", ")). Choose different keys.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            Section {
                Button("Restore Default Shortcuts") {
                    model.prefs.shortcuts = Preferences().shortcuts
                }
            }
        }
    }
}

private struct ShortcutRecorder: View {
    @EnvironmentObject var model: AppModel
    let id: ShortcutID
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(recording ? "Type Shortcut…" : (model.prefs.shortcuts[id]?.display ?? "Record Shortcut"))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(recording ? Color.accentColor : (model.prefs.shortcuts[id] == nil ? .secondary : .primary))
                .frame(minWidth: 110)
        }
        .buttonStyle(.bordered)
        .onDisappear { stop() }
        .accessibilityLabel("\(id.title) shortcut")
        .accessibilityValue(model.prefs.shortcuts[id]?.display ?? "None")
    }

    private func start() {
        recording = true
        model.suspendShortcuts()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case kVK_Escape:
                stop()
            case kVK_Delete, kVK_ForwardDelete:
                model.prefs.shortcuts[id] = nil
                stop()
            default:
                guard let combo = KeyCombo(event: event) else {
                    NSSound.beep()
                    return nil
                }
                var shortcuts = model.prefs.shortcuts
                for (other, existing) in shortcuts where existing == combo && other != id { shortcuts[other] = nil }
                shortcuts[id] = combo
                model.prefs.shortcuts = shortcuts
                stop()
            }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard recording else { return }
        recording = false
        model.registerShortcuts()
    }
}

private struct HomeLayoutPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section {
                OrderedPicker(
                    all: HomeCardID.allCases,
                    selection: $model.prefs.homeCards,
                    limit: 4,
                    title: \.title,
                    symbol: \.symbol
                )
            } header: {
                Text("Cards")
            } footer: {
                Text("Up to four cards sit side by side on the Home tab, in this order. Now Playing takes the most room.")
            }
        }
    }
}

private struct TabsPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section {
                OrderedPicker(all: TabID.allCases, selection: $model.prefs.tabOrder, limit: nil, title: \.title, symbol: \.symbol, summary: \.summary)
            } header: {
                Text("Tabs in the Island Header")
            } footer: {
                Text("Turned-off tabs stay available from the Command Palette (\(model.prefs.shortcuts[.commandPalette]?.display ?? "no shortcut")).")
            }
        }
    }
}

/// Toggle items on and arrange the ones that are on.
private struct OrderedPicker<Item: Identifiable & Hashable>: View {
    let all: [Item]
    @Binding var selection: [Item]
    let limit: Int?
    let title: KeyPath<Item, String>
    let symbol: KeyPath<Item, String>
    var summary: KeyPath<Item, String>?

    var body: some View {
        let ordered = selection + all.filter { !selection.contains($0) }
        ForEach(ordered) { item in
            let index = selection.firstIndex(of: item)
            HStack(spacing: 10) {
                Image(systemName: item[keyPath: symbol]).frame(width: 20).foregroundStyle(index == nil ? .secondary : Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item[keyPath: title])
                    if let summary { Text(item[keyPath: summary]).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                if let index {
                    Button { move(index, by: -1) } label: { Image(systemName: "chevron.up") }
                        .disabled(index == 0)
                        .accessibilityLabel("Move \(item[keyPath: title]) Up")
                    Button { move(index, by: 1) } label: { Image(systemName: "chevron.down") }
                        .disabled(index == selection.count - 1)
                        .accessibilityLabel("Move \(item[keyPath: title]) Down")
                }
                Toggle(item[keyPath: title], isOn: Binding(
                    get: { index != nil },
                    set: { on in
                        if on { selection.append(item) } else if selection.count > 1 { selection.removeAll { $0 == item } }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled((index == nil && limit.map { selection.count >= $0 } == true) || (index != nil && selection.count == 1))
            }
            .buttonStyle(.borderless)
        }
        .animation(.default, value: selection)
    }

    private func move(_ index: Int, by offset: Int) {
        let target = index + offset
        guard selection.indices.contains(target) else { return }
        selection.swapAt(index, target)
    }
}

private struct NowPlayingPane: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var media: NowPlayingService

    var body: some View {
        Form {
            Section {
                LabeledContent("Source") {
                    if let error = media.bridgeError {
                        Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    } else if media.hasMedia {
                        Text("\(media.title) — \(media.appName)").lineLimit(1)
                    } else {
                        Text("Connected, nothing playing").foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Mochy reads the same Now Playing session as Control Center, so it follows Music, Spotify, Podcasts, and videos in Safari or Chrome, including YouTube.")
            }
            Section("Appearance") {
                Toggle("Tint with Album Colors", isOn: $model.prefs.artworkTint)
                Toggle("Show New Tracks as an Alert", isOn: $model.prefs.trackChangePeek)
            }
            Section {
                SecondsSlider(title: "Keep Paused Media Beside the Notch", value: $model.prefs.keepPausedMediaSeconds, range: 0 ... 120, step: 5, decimals: 0)
            } footer: {
                Text("After this, a paused player leaves the notch until playback resumes.")
            }
        }
    }
}

private struct CalendarPane: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var calendar: CalendarService

    var body: some View {
        Form {
            Section("Access") {
                AccessRow(title: "Calendar", detail: "Events from every calendar in the Calendar app", access: calendar.eventAccess, request: calendar.requestAccess, settings: { calendar.openPrivacySettings() })
                AccessRow(title: "Reminders", detail: "Incomplete reminders due today", access: calendar.reminderAccess, request: calendar.requestReminderAccess, settings: { calendar.openPrivacySettings(reminders: true) })
            }
            Section("Today") {
                Toggle("Show All-Day Events", isOn: $model.prefs.showAllDayEvents)
                Toggle("Show Reminders in To-Do", isOn: $model.prefs.showRemindersInTodo)
            }
            Section {
                Toggle("Alert Before Events", isOn: $model.prefs.eventAlerts)
                Stepper(value: $model.prefs.eventAlertMinutes, in: 1 ... 30) {
                    LabeledContent("Lead Time", value: "\(model.prefs.eventAlertMinutes) min")
                }
                .disabled(!model.prefs.eventAlerts)
            } footer: {
                Text("Events with a Zoom, Meet, Teams, Webex or FaceTime link get a Join button.")
            }
        }
    }
}

private struct ShelfPane: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var shelf: ShelfService

    var body: some View {
        Form {
            Section("Adding Files") {
                Toggle("Open the Shelf When Dragging Files to the Notch", isOn: $model.prefs.openShelfOnFileDrag)
                Toggle("Add New Screenshots", isOn: $model.prefs.screenshotsToShelf)
                Toggle("Add Finished Downloads", isOn: $model.prefs.downloadsToShelf)
            }
            Section {
                Toggle("Remove Files After AirDrop", isOn: $model.prefs.removeAfterAirDrop)
            } header: {
                Text("AirDrop")
            } footer: {
                Text("Drop files on the AirDrop tile in the Shelf to pick a nearby device.")
            }
            Section {
                LabeledContent("Files on the Shelf", value: "\(shelf.items.count)")
                Button("Clear the Shelf", role: .destructive) { shelf.clear() }
                    .disabled(shelf.items.isEmpty)
            } footer: {
                Text("The Shelf holds copies, so clearing it never deletes your originals.")
            }
        }
    }
}

private struct ClipboardPane: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var clipboard: ClipboardService

    var body: some View {
        Form {
            Section {
                Toggle("Keep Clipboard History", isOn: $model.prefs.clipboardHistory)
                Picker("Remember", selection: $model.prefs.clipboardLimit) {
                    ForEach([20, 40, 80, 150], id: \.self) { Text("\($0) Items").tag($0) }
                }
                .disabled(!model.prefs.clipboardHistory)
                Toggle("Remove Tracking Parameters from Copied Links", isOn: $model.prefs.stripLinkTrackers)
            } footer: {
                Text("Mochy skips passwords and anything else apps mark as private. History stays on this Mac; only pinned items survive a restart.")
            }
            Section {
                Button("Clear History", role: .destructive) { clipboard.clearHistory() }
                    .disabled(clipboard.items.isEmpty)
            }
        }
    }
}

private struct PomodoroPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section("Durations") {
                MinutesStepper(title: "Focus", value: $model.prefs.focusMinutes, range: 5 ... 120, step: 5)
                MinutesStepper(title: "Short Break", value: $model.prefs.shortBreakMinutes, range: 1 ... 30, step: 1)
                MinutesStepper(title: "Long Break", value: $model.prefs.longBreakMinutes, range: 5 ... 60, step: 5)
                Stepper(value: $model.prefs.roundsBeforeLongBreak, in: 2 ... 8) {
                    LabeledContent("Rounds Before a Long Break", value: "\(model.prefs.roundsBeforeLongBreak)")
                }
            }
            Section("Behavior") {
                Toggle("Start the Next Phase Automatically", isOn: $model.prefs.autoStartNextPhase)
                Toggle("Play a Sound When a Phase Ends", isOn: $model.prefs.timerSound)
            }
        }
    }
}

private struct CaffeinePane: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var caffeine: CaffeineService

    var body: some View {
        Form {
            Section {
                LabeledContent("Status", value: caffeine.isActive ? (caffeine.endsAt == nil ? "On until turned off" : "On · \(caffeine.remainingDescription) left") : "Off")
                Button(caffeine.isActive ? "Turn Off" : "Turn On") { model.toggleCaffeine() }
            }
            Section {
                Picker("Default Duration", selection: $model.prefs.caffeineDefault) {
                    ForEach(CaffeineDuration.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Keep the Display On", isOn: $model.prefs.caffeineKeepsDisplayOn)
            } footer: {
                Text("Caffeine stops your Mac from sleeping while it’s on. Right-click the Caffeine control in the island for other durations.")
            }
        }
    }
}

private struct DeveloperPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Local API", isOn: $model.prefs.apiEnabled)
                LabeledContent("Port") {
                    TextField("Port", value: $model.prefs.apiPort, format: .number.grouping(.never))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                LabeledContent("Token") {
                    HStack {
                        Text(model.prefs.apiToken).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        Button("Regenerate") { model.prefs.apiToken = Preferences.newToken() }
                    }
                }
            } footer: {
                Text("Only accepts connections from this Mac. Send the token in an X-Mochy-Token header.")
            }
            Section("Example") {
                Text("curl -X POST -H 'X-Mochy-Token: \(model.prefs.apiToken)' http://127.0.0.1:\(String(model.prefs.apiPort))/show -d '{\"title\":\"Build finished\",\"subtitle\":\"main\"}'")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Text("GET /status · POST /expand · POST /show")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct AboutPane: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mochy").font(.title2.weight(.semibold))
                        Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            Section("Good to Know") {
                Text("Mochy doesn’t replace the system volume and brightness indicators.")
                Text("CPU and GPU temperatures aren’t shown; they need private sensor access.")
                Text("Now Playing uses the system media session through a small bundled helper. A future macOS update could change that session.")
            }
            Section {
                Button("Quit Mochy") { NSApp.terminate(nil) }
            }
        }
    }
}

// MARK: Controls

private struct SecondsSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var decimals = 2

    var body: some View {
        LabeledContent {
            HStack {
                Slider(value: $value, in: range, step: step).frame(maxWidth: 220)
                Text(String(format: "%.\(decimals)f s", value)).monospacedDigit().foregroundStyle(.secondary).frame(width: 52, alignment: .trailing)
            }
        } label: {
            Text(title)
        }
    }
}

private struct MinutesStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        Stepper(value: $value, in: range, step: step) {
            LabeledContent(title, value: "\(Int(value)) min")
        }
    }
}
