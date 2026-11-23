import AppKit
import Carbon.HIToolbox
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, island, appearance, behavior, activities, shortcuts
    case home, tabs, dock
    case nowPlaying, calendar, shelf, clipboard, todo, pomodoro, caffeine
    case developer, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .island: "Island"
        case .appearance: "Appearance"
        case .behavior: "Behavior"
        case .activities: "Live Activities"
        case .shortcuts: "Key Shortcuts"
        case .home: "Home Layout"
        case .tabs: "Island Order"
        case .dock: "Dock Shortcuts"
        case .nowPlaying: "Now Playing"
        case .calendar: "Calendar"
        case .shelf: "Shelf"
        case .clipboard: "Clipboard"
        case .todo: "To-Do"
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
        case .appearance: "paintbrush.fill"
        case .behavior: "slider.horizontal.3"
        case .activities: "bell.badge.fill"
        case .shortcuts: "command"
        case .home: "square.grid.2x2.fill"
        case .tabs: "rectangle.3.group.fill"
        case .dock: "dock.rectangle"
        case .nowPlaying: "play.fill"
        case .calendar: "calendar"
        case .shelf: "tray.full.fill"
        case .clipboard: "doc.on.clipboard.fill"
        case .todo: "checklist"
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
        case .appearance: .pink
        case .behavior: .orange
        case .activities: .red
        case .shortcuts: .indigo
        case .home: .blue
        case .tabs: .cyan
        case .dock: .mint
        case .nowPlaying: .pink
        case .calendar: .red
        case .shelf: .teal
        case .clipboard: .purple
        case .todo: .orange
        case .pomodoro: .orange
        case .caffeine: .brown
        case .developer: .green
        }
    }

    static let groups: [[SettingsPane]] = [
        [.general, .island, .appearance, .behavior, .activities, .shortcuts],
        [.home, .tabs, .dock],
        [.nowPlaying, .calendar, .shelf, .clipboard, .todo, .pomodoro, .caffeine],
        [.developer, .about],
    ]
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var pane: SettingsPane?

    init(initialPane: SettingsPane = .general) {
        _pane = State(initialValue: initialPane)
    }

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
            case .appearance: AppearancePane()
            case .behavior: BehaviorPane()
            case .activities: ActivitiesPane()
            case .shortcuts: ShortcutsPane()
            case .home: HomeLayoutPane()
            case .tabs: TabsPane()
            case .dock: DockPane()
            case .nowPlaying: NowPlayingPane(media: model.nowPlaying)
            case .calendar: CalendarPane(calendar: model.calendar)
            case .shelf: ShelfPane(shelf: model.shelf)
            case .clipboard: ClipboardPane(clipboard: model.clipboard)
            case .todo: TodoSettingsPane()
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
                Toggle("Launch at Login", isOn: $model.prefs.launchAtLogin)
                Toggle("Clipboard Button in the Menu Bar", isOn: $model.prefs.menuBarClipboard)
                Toggle("To-Do Button in the Menu Bar", isOn: $model.prefs.menuBarTodo)
                Toggle("Follow the Pointer to Other Displays", isOn: $model.prefs.followPointerDisplay)
            } footer: {
                Text("Mochy itself stays out of the menu bar. The Clipboard and To-Do buttons are optional and only open that tab. Settings stays available with \(model.prefs.shortcuts[.settings]?.display ?? "the Settings shortcut") or by opening Mochy again from Applications.")
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
            Section {
                Picker("Size", selection: $model.prefs.panelSize) {
                    ForEach(PanelSize.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Hide Island in Screenshots", isOn: $model.prefs.hideIslandFromScreenshots)
            } header: {
                Text("Layout")
            } footer: {
                Text("Opening, closing and which display Mochy uses live in Behavior. Hidden screenshots omit the island from Capture and recordings.")
            }
            Section {
                PrefSlider(title: "Section Icon Gap", value: $model.prefs.tabIconGap, range: 0 ... 16, step: 1, unit: "pt")
            } header: {
                Text("Section Icons")
            } footer: {
                Text("Space around and between the tabs on the left of the island.")
            }
        }
    }
}

private struct BehaviorPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $model.prefs.launchAtLogin)
                Toggle("Expand on Hover", isOn: $model.prefs.openOnHover)
                SecondsSlider(title: "Hover Delay", value: $model.prefs.hoverDelay, range: 0 ... 1, step: 0.05)
                    .disabled(!model.prefs.openOnHover)
                Picker("Default Tab", selection: defaultTabBinding) {
                    Text("Previous Tab").tag("previous")
                    ForEach(TabID.allCases.filter { $0 != .stats }) { tab in
                        Text(tab.title).tag(tab.rawValue)
                    }
                }
                Toggle("Open on Current Activity", isOn: $model.prefs.openOnCurrentActivity)
            } header: {
                Text("Opening")
            } footer: {
                Text("Launch at Login starts Mochy when you log in to this Mac. Expand on Hover opens the panel when the pointer rests on the closed pill. Default Tab is the tab after the panel has been closed a while. Open on Current Activity prefers Now Playing or Timer when those are running.")
            }

            Section {
                Toggle("Auto Collapse", isOn: $model.prefs.closeOnMouseExit)
                SecondsSlider(title: "Collapse Delay", value: $model.prefs.closeDelay, range: 0 ... 2, step: 0.1)
                    .disabled(!model.prefs.closeOnMouseExit)
                PrefSlider(title: "Cursor on the Island", value: $model.prefs.idleTimeout, range: 0 ... 120, step: 5) { value in
                    value == 0 ? "Never" : "\(Int(value)) s"
                }
                PrefSlider(title: "Cursor off the Island", value: $model.prefs.idleTimeoutAway, range: 0 ... 15, step: 1) { value in
                    value == 0 ? "Use Collapse Delay" : "\(Int(value)) s"
                }
            } header: {
                Text("Closing")
            } footer: {
                Text("Auto Collapse closes the panel after the pointer leaves. Collapse Delay is that wait when Cursor off the Island is set to Use Collapse Delay. Cursor on the Island closes it while the pointer is still resting on it; Never keeps it open while hovered. Cursor off the Island waits up to 15 seconds after the pointer leaves.")
            }

            Section {
                Picker("Show On", selection: $model.prefs.islandScreen) {
                    ForEach(IslandScreen.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Visibility")
            } footer: {
                Text("Choose which connected displays show Mochy.")
            }
        }
    }

    private var defaultTabBinding: Binding<String> {
        Binding(
            get: { model.prefs.rememberLastTab ? "previous" : model.prefs.defaultTab.rawValue },
            set: { value in
                if value == "previous" {
                    model.prefs.rememberLastTab = true
                } else {
                    model.prefs.rememberLastTab = false
                    if let tab = TabID(rawValue: value) { model.prefs.defaultTab = tab }
                }
            }
        )
    }
}

private struct AppearancePane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section {
                PrefSlider(title: "Size", value: $model.prefs.closedPillScale, range: 0.85 ... 1.35, step: 0.05, minLabel: "S", maxLabel: "L") { value in
                    String(format: "%.2f×", value)
                }
            } header: {
                Text("Closed Pill")
            }
            Section {
                PrefSlider(title: "Height", value: $model.prefs.activityHeightExtra, range: -12 ... 18, step: 1, unit: "pt")
                PrefSlider(title: "Width", value: $model.prefs.activityWidthExtra, range: 0 ... 28, step: 1, unit: "pt")
            } header: {
                Text("Live Activity Pill")
            } footer: {
                Text("Height can go below zero to shrink the live activity pill toward the camera housing. Width adds room on each ear.")
            }
            Section {
                Toggle("Haptic Feedback on Hover", isOn: $model.prefs.hapticFeedback)
                Toggle("Haptic Feedback on Clicks", isOn: $model.prefs.hapticOnClick)
            } header: {
                Text("Feel")
            }
            Section {
                Toggle("Glass Surface", isOn: $model.prefs.glassSurface)
                Picker("Translucency", selection: $model.prefs.translucency) {
                    ForEach(TranslucencyProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
            } header: {
                Text("Surface")
            } footer: {
                Text(model.prefs.translucency.summary)
            }
        }
    }
}

private struct DockPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Show Dock Shortcuts", isOn: $model.prefs.dockShortcutsEnabled)
                Toggle("To-Do beside the Dock", isOn: $model.prefs.dockTodo)
                Toggle("Clipboard beside the Dock", isOn: $model.prefs.dockClipboard)
                Toggle("Audio Devices beside the Dock", isOn: $model.prefs.dockAudio)
            } header: {
                Text("Dock Shortcuts")
            } footer: {
                Text("Show Dock Shortcuts hides every chip and restores the same chips, positions, and glass when you turn it back on. The chips sit next to the Dock at Dock height — they are not Dock icons. Click one for a compact glass card. Press Esc to close that card.")
            }
            Section {
                PrefSlider(title: "Transparency", value: $model.prefs.dockIconTransparency, range: 0 ... 1, step: 0.05) { value in
                    String(format: "%.0f%%", value * 100)
                }
                PrefSlider(title: "Reflection", value: $model.prefs.dockIconReflection, range: 0 ... 1, step: 0.05) { value in
                    String(format: "%.0f%%", value * 100)
                }
            } header: {
                Text("Glass")
            } footer: {
                Text("Transparency lets the desktop show through the shortcut icons. Reflection adds a light sheen across that glass. Both are kept when the shortcuts are hidden.")
            }
            Section {
                PrefSlider(title: "Offset", value: $model.prefs.dockOffsetLeft, range: -350 ... 350, step: 1, unit: "pt")
            } header: {
                Text("Left Horizontal")
            } footer: {
                Text("Moves the Bluetooth chip on its own. Positive is to the right, negative is to the left.")
            }
            Section {
                PrefSlider(title: "Offset", value: $model.prefs.dockOffsetRight, range: -350 ... 350, step: 1, unit: "pt")
            } header: {
                Text("Right Horizontal")
            } footer: {
                Text("Moves the To-Do and Clipboard chips on their own. Positive is to the right, negative is to the left.")
            }
            Section {
                PrefSlider(title: "Offset", value: $model.prefs.dockOffsetY, range: 0 ... 480, step: 1, unit: "pt")
                Button("Reset Position") {
                    model.prefs.dockOffsetLeft = 0
                    model.prefs.dockOffsetRight = 0
                    model.prefs.dockOffsetY = 0
                }
                .disabled(model.prefs.dockOffsetLeft == 0 && model.prefs.dockOffsetRight == 0 && model.prefs.dockOffsetY == 0)
            } header: {
                Text("Lower")
            } footer: {
                Text("At 0 the chips sit on the Dock’s baseline. Lower drops both groups down from the Dock, up to 480 points.")
            }
            Section {
                PrefSlider(title: "Icon Size", value: $model.prefs.dockIconScale, range: 0.5 ... 1, step: 0.05, minLabel: "S", maxLabel: "L") { value in
                    String(format: "%.0f%%", value * 100)
                }
            } header: {
                Text("Icon Size")
            } footer: {
                Text("Shrinks the To-Do, Clipboard and AirPods chips beside the Dock.")
            }
            Section {
                Toggle("Clipboard Button", isOn: $model.prefs.menuBarClipboard)
                Toggle("To-Do Button", isOn: $model.prefs.menuBarTodo)
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("Menu bar buttons open the same compact card, not the island.")
            }
        }
    }
}

private struct ActivitiesPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Always Show Now Playing as a Pill", isOn: $model.prefs.alwaysShowNowPlaying)
                Toggle("Timers", isOn: $model.prefs.timerActivity)
                Toggle("Download Progress", isOn: $model.prefs.downloadActivity)
                Toggle("Caffeine", isOn: $model.prefs.caffeineActivity)
            } header: {
                Text("Beside the Notch")
            } footer: {
                Text("When Always Show Now Playing is off, media never opens the compressed pill. The same control sits next to Pin in the island. Volume and brightness stay with the system HUD.")
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

struct ShortcutsPane: View {
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
                    all: HomeCardID.allCases.filter { $0 != .system },
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
                OrderedPicker(all: TabID.allCases.filter { $0 != .stats }, selection: $model.prefs.tabOrder, limit: nil, title: \.title, symbol: \.symbol, summary: \.summary)
            } header: {
                Text("Order in the Island")
            } footer: {
                Text("Move Home, Now Playing, Shelf, Clipboard, To-Do, Calendar and the other tabs up or down. Turned-off tabs stay available from the Command Palette (\(model.prefs.shortcuts[.commandPalette]?.display ?? "no shortcut")).")
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
    @State private var addingSite = false
    @State private var siteDraft = ""

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
                Toggle("Always Show the Compressed Now Playing Pill", isOn: $model.prefs.alwaysShowNowPlaying)
            }
            Section {
                SecondsSlider(title: "Keep Paused Media Beside the Notch", value: $model.prefs.keepPausedMediaSeconds, range: 0 ... 120, step: 5, decimals: 0)
            } footer: {
                Text("After this, a paused player leaves the notch until playback resumes. Album art for a paused session is dropped after 15 seconds so the next track cannot inherit it.")
            }
            Section {
                ForEach(model.prefs.mediaAllowlist, id: \.self) { host in
                    HStack {
                        Text(host)
                            .lineLimit(1)
                        Spacer()
                        Button(role: .destructive) {
                            model.prefs.mediaAllowlist.removeAll { $0 == host }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove \(host)")
                    }
                }
                Button {
                    siteDraft = ""
                    addingSite = true
                } label: {
                    Label("Add Site", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Allowed Sites")
            } footer: {
                Text("Only these websites can open the Now Playing pill. Every other website stays off it. youtube.com also allows youtu.be, and x.com also allows Twitter. An empty list blocks every website. Music and Spotify are not websites, so they still show.")
            }
        }
        .alert("Allow a Site", isPresented: $addingSite) {
            TextField("youtube.com", text: $siteDraft)
            Button("Add") { addAllowedSite() }
            Button("Cancel", role: .cancel) { siteDraft = "" }
        } message: {
            Text("Enter a website. Only playback from that site can open the Now Playing live activity.")
        }
    }

    private func addAllowedSite() {
        var value = siteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.contains("://") { value = "https://\(value)" }
        if let host = URL(string: value)?.host, !host.isEmpty {
            value = host
        }
        value = value.lowercased()
        if value.hasPrefix("www.") { value = String(value.dropFirst(4)) }
        guard !value.isEmpty else { return }
        if !model.prefs.mediaAllowlist.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
            model.prefs.mediaAllowlist.append(value)
        }
        siteDraft = ""
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
                Picker("Remove After", selection: $model.prefs.shelfLifetime) {
                    ForEach(ShelfLifetime.allCases) { lifetime in
                        Text(lifetime.title).tag(lifetime)
                    }
                }
            } header: {
                Text("Automatic Removal")
            } footer: {
                Text("A shelf copy is removed after this long. Never keeps it until you clear it. Your original file is not deleted.")
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
                Toggle(isOn: $model.prefs.clipboardHistory) {
                    clipboardRow("doc.on.clipboard.fill", .cyan, "Clipboard History", "Keep recent copies — one click to restore")
                }
                .toggleStyle(.switch)
            } footer: {
                Text("A searchable history of what you copy, kept on this Mac. In the island, 1–9 paste the newest snippets.")
            }

            Section {
                LabeledContent {
                    Text("\(min(clipboard.items.count, model.prefs.clipboardLimit)) of \(model.prefs.clipboardLimit)")
                        .foregroundStyle(.secondary)
                } label: {
                    clipboardRow("tray.full.fill", .gray, "Stored Items", nil)
                }
                VStack(alignment: .leading, spacing: 8) {
                    clipboardRow("number", .indigo, "History Limit", nil)
                    Picker("History Limit", selection: $model.prefs.clipboardLimit) {
                        ForEach([40, 100, 200, 500], id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(!model.prefs.clipboardHistory)
                }
                Toggle(isOn: $model.prefs.clipboardPersist) {
                    clipboardRow("internaldrive.fill", .cyan, "Keep History After Quitting", "Your history is still there after a restart. Stored only on this Mac.")
                }
                .disabled(!model.prefs.clipboardHistory)
                Toggle(isOn: captureSound) {
                    clipboardRow("speaker.wave.2.fill", .blue, "Capture Sound", "Play a short sound each time a new copy is saved")
                }
                .disabled(!model.prefs.clipboardHistory)
                HStack {
                    clipboardRow("waveform", .teal, "Sound", nil)
                    Spacer()
                    Picker("Sound", selection: Binding(
                        get: { model.prefs.clipboardSound == .none ? ClipboardSound.pop : model.prefs.clipboardSound },
                        set: { model.prefs.clipboardSound = $0 }
                    )) {
                        ForEach(ClipboardSound.allCases.filter { $0 != .none }) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                    Button {
                        model.playClipboardSound()
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(model.prefs.clipboardSound == .none)
                }
                HStack {
                    clipboardRow("trash.fill", .red, "Clear History", "Forget every stored copy now")
                    Spacer()
                    Button("Clear…", role: .destructive) { clipboard.clearHistory() }
                        .disabled(clipboard.items.filter { !$0.pinned }.isEmpty)
                }
            } header: {
                Text("History")
            }

            Section {
                Toggle(isOn: $model.prefs.stripLinkTrackers) {
                    clipboardRow("link.badge.minus", .orange, "Remove Trackers from Copied URLs", "Strip utm, fbclid and similar parameters when a copy is a link")
                }
                .disabled(!model.prefs.clipboardHistory)
            } header: {
                Text("Links")
            } footer: {
                Text("Copied URLs show an open-link control in the Clipboard list. Turn this on to clean tracking parameters from those URLs as they are copied.")
            }

            Section {
                LabeledContent {
                    Text(clipboard.items.contains(where: \.pinned) ? "\(clipboard.items.filter(\.pinned).count)" : "Empty")
                        .foregroundStyle(.secondary)
                } label: {
                    clipboardRow("pin.fill", .orange, "Pinned", nil)
                }
            } header: {
                Text("Saved Lists")
            } footer: {
                Text("Pin copies you reuse. Right-click any item in the Clipboard tab and choose Pin. Pinned items never age out.")
            }
        }
    }

    private var captureSound: Binding<Bool> {
        Binding(
            get: { model.prefs.clipboardSound != .none },
            set: { on in
                model.prefs.clipboardSound = on ? (model.prefs.clipboardSound == .none ? .pop : model.prefs.clipboardSound) : .none
            }
        )
    }

    private func clipboardRow(_ symbol: String, _ color: Color, _ title: String, _ subtitle: String?) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color.gradient))
        }
    }
}

struct TodoSettingsPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $model.prefs.todoSoundOnAdd) {
                    todoRow("speaker.wave.2.fill", .blue, "Sound When Adding", "Play a sound when you add a to-do")
                }
                Toggle(isOn: $model.prefs.todoSoundOnRemove) {
                    todoRow("speaker.wave.2.fill", .teal, "Sound When Removing", "Play a sound when you tick off or delete a to-do")
                }
            } header: {
                Text("Sounds")
            }

            Section {
                Picker("New Items", selection: $model.prefs.todoNewestOnTop) {
                    Text("Top").tag(true)
                    Text("Bottom").tag(false)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Sort Order")
            } footer: {
                Text("Top puts the newest to-do at the start of the list. Bottom puts it at the end.")
            }

            Section {
                Toggle(isOn: $model.prefs.todoRecognizeURLs) {
                    todoRow("link", .blue, "Recognize URLs", "An https link is shown in blue. Click the text to open it.")
                }
                Toggle(isOn: $model.prefs.todoTrimURLPrefix) {
                    todoRow("textformat", .indigo, "Remove Prefix from URLs", "Hide https and www at the start of a link")
                }
                .disabled(!model.prefs.todoRecognizeURLs)
                Toggle(isOn: $model.prefs.todoStripTrackers) {
                    todoRow("link.badge.minus", .orange, "Remove Trackers from URLs", "Strip utm, fbclid and similar parameters when a to-do link is opened")
                }
                .disabled(!model.prefs.todoRecognizeURLs)
            } header: {
                Text("Links")
            }
        }
    }

    private func todoRow(_ symbol: String, _ color: Color, _ title: String, _ subtitle: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color.gradient))
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

struct AboutPane: View {
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
            Section("Developer Details") {
                LabeledContent("Developer", value: "Vighnesh")
                Link("github.com/vighnesh-7", destination: URL(string: "https://github.com/vighnesh-7")!)
                Link("Open sourced at github.com/vighnesh-7/mochy", destination: URL(string: "https://github.com/vighnesh-7/mochy")!)
                Link("vighnesh-vangari.vercel.app", destination: URL(string: "https://vighnesh-vangari.vercel.app/")!)
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

private struct PrefSlider: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double = 1
    var unit: String = ""
    var minLabel: String? = nil
    var maxLabel: String? = nil
    var display: ((Double) -> String)? = nil

    init(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double = 1, unit: String = "", minLabel: String? = nil, maxLabel: String? = nil, display: ((Double) -> String)? = nil) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.minLabel = minLabel
        self.maxLabel = maxLabel
        self.display = display
    }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                if let minLabel {
                    Text(minLabel).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
                Slider(value: $value, in: range, step: step)
                if let maxLabel {
                    Text(maxLabel).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
                Text(boxLabel)
                    .font(.body.monospacedDigit())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(minWidth: 62)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
            }
        }
    }

    private var boxLabel: String {
        if let display { return display(value) }
        let number = abs(value - value.rounded()) < 0.001 ? "\(Int(value.rounded()))" : String(format: "%.2f", value)
        return unit.isEmpty ? number : "\(number) \(unit)"
    }
}

private struct SecondsSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var decimals = 2

    var body: some View {
        PrefSlider(title: title, value: $value, range: range, step: step) { value in
            String(format: "%.\(decimals)f s", value)
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
