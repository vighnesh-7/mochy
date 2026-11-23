import AppKit
import Combine
import CoreGraphics
import Foundation
import SwiftUI

struct NotchGeometry: Equatable {
    var width: CGFloat
    var height: CGFloat
    var hasNotch: Bool

    static let fallback = NotchGeometry(width: 190, height: 32, hasNotch: false)

    static func of(_ screen: NSScreen) -> NotchGeometry {
        if screen.safeAreaInsets.top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            return NotchGeometry(width: screen.frame.width - left.width - right.width, height: screen.safeAreaInsets.top, hasNotch: true)
        }
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        return NotchGeometry(width: 190, height: max(menuBar, 24), hasNotch: false)
    }
}

enum LiveActivity: Equatable {
    case media, timer, download, volume, brightness, caffeine, charging
}

enum AlertAction: Equatable {
    case open(URL)
    case reveal(URL)
    case showTab(TabID)
}

struct IslandAlert: Identifiable, Equatable {
    enum Style: Equatable { case standard, track }
    let id = UUID()
    var style: Style = .standard
    var symbol: String
    var tint: Color
    var title: String
    var subtitle: String
    var actionTitle: String?
    var action: AlertAction?
    var duration: TimeInterval = 4
    /// Timer and pomodoro banners stay until the pointer reaches the island.
    var persistsUntilHover = false
}

struct PaletteCommand: Identifiable {
    let id: String
    let title: String
    let symbol: String
    var detail: String = ""
    let run: () -> Void
}

@MainActor
final class AppModel: ObservableObject {
    @Published var prefs: Preferences {
        didSet {
            guard prefs != oldValue else { return }
            prefs.save()
            applyPreferences(previous: oldValue)
        }
    }

    @Published private(set) var isExpanded = false
    var openDockClipboard: (() -> Void)?
    @Published var tab: TabID = .home
    @Published var pinned = false
    @Published var paletteOpen = false
    @Published private(set) var alert: IslandAlert?
    @Published private(set) var activity: LiveActivity?
    @Published var fileDragActive = false
    /// True while a shelf menu or context menu is open, so the island does not collapse underneath it.
    var menuTracking = false
    @Published var notch = NotchGeometry.fallback
    @Published var colorPickerResult: String?
    @Published var shortcutFailures: [String] = []

    /// Tab views ask for keyboard focus (to-do field, clipboard search) through this.
    @Published var focusRequest = UUID()
    var wantsKeyboard = false

    let nowPlaying = NowPlayingService()
    let battery = BatteryMonitor()
    let caffeine = CaffeineService()
    let stats = SystemStatsService()
    let calendar = CalendarService()
    let shelf = ShelfService()
    let clipboard = ClipboardService()
    let todo = TodoStore()
    let downloads = DownloadMonitor()
    let timer = FocusTimer()
    let volume = VolumeMonitor()
    let brightness = BrightnessMonitor()
    /// The app that was in front before the island took the keyboard, so a numbered snippet can be pasted back into it.
    var previousFrontApp: NSRunningApplication?
    let weather = WeatherService()
    let notes = NotesService()
    let calculator = CalculatorService()
    let launcher = LauncherService()
    let screenshots = ScreenshotWatcher()

    var openSettings: (() -> Void)?
    var onShortcutsChanged: (() -> Void)?

    private var bag = Set<AnyCancellable>()
    private var alertWork: DispatchWorkItem?
    private let chimePlayer = ChimePlayer()
    private var alertedEvents = Set<String>()
    private var clock: Timer?

    init() {
        prefs = Preferences.load()
        if Preferences.needsHUDSave {
            Preferences.needsHUDSave = false
            prefs.save()
        }
        if let first = prefs.tabOrder.first(where: { $0 != .stats }) { tab = first }
    }

    // MARK: Lifecycle

    func start() {
        applyServiceSettings()
        nowPlaying.start()
        battery.start()
        calendar.start()
        shelf.load()
        clipboard.start()
        todo.load()
        downloads.start()
        volume.start()
        brightness.start()
        notes.load()
        clipboard.onInserted = { [weak self] in self?.playClipboardSound() }
        todo.onAdded = { [weak self] in
            guard let self, self.prefs.todoSoundOnAdd else { return }
            self.playTodoAddedSound()
        }
        todo.onCompleted = { [weak self] in
            guard let self, self.prefs.todoSoundOnRemove else { return }
            self.playTodoCompleteSound()
        }
        todo.onRemoved = { [weak self] in
            guard let self, self.prefs.todoSoundOnRemove else { return }
            self.playTodoCompleteSound()
        }
        if prefs.screenshotsToShelf { screenshots.start() }
        bindEvents()
        registerShortcuts()
        let clock = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.everySecond() }
        }
        clock.tolerance = 0.45
        RunLoop.main.add(clock, forMode: .common)
        self.clock = clock
        recomputeActivity()
    }

    func stop() {
        nowPlaying.stop()
        caffeine.stop()
        HotKeyCenter.shared.unregisterAll()
    }

    // MARK: Island state

    var visibleTabs: [TabID] { prefs.tabOrder.filter { $0 != .stats } }

    /// The expanded header shares the camera band; 34 pt keeps 22 pt tab pills clear of the edge.
    var headerHeight: CGFloat { max(notch.height, 34) }

    /// Space inside the expanded body for the tab, above the bottom rounding.
    static let expandedContentTop: CGFloat = 4
    static let expandedContentBottom: CGFloat = 4

    var islandBodySize: CGSize {
        if isExpanded {
            return CGSize(
                width: prefs.panelSize.width + CGFloat(prefs.activityWidthExtra),
                height: headerHeight
                    + prefs.panelSize.contentHeight
                    + Self.expandedContentTop
                    + Self.expandedContentBottom
            )
        }
        if alert != nil {
            return CGSize(width: max(notch.width + 280, 500), height: notch.height + 62)
        }
        let scale = CGFloat(max(0.8, min(prefs.closedPillScale, 1.4)))
        if let activity {
            let extra = CGFloat(prefs.activityWidthExtra)
            let height = max(22, notch.height + CGFloat(prefs.activityHeightExtra))
            return CGSize(width: notch.width * scale + 2 * (earWidth(activity) + extra), height: height)
        }
        return CGSize(width: notch.width * scale, height: notch.height * scale)
    }

    var cornerRadii: (top: CGFloat, bottom: CGFloat) {
        if isExpanded { return (14, 32) }
        if alert != nil { return (12, 24) }
        return (6, notch.hasNotch ? 12 : 10)
    }

    static func earWidth(_ activity: LiveActivity) -> CGFloat {
        switch activity {
        case .media: 64
        case .caffeine, .charging: 52
        case .timer: 96
        case .download: 72
        case .volume, .brightness: 88
        }
    }

    func earWidth(_ activity: LiveActivity) -> CGFloat {
        Self.earWidth(activity) + CGFloat(prefs.activityWidthExtra)
    }

    func expand(tab newTab: TabID? = nil, keyboard: Bool = false) {
        if let newTab, newTab != .stats {
            if !prefs.tabOrder.contains(newTab) { prefs.tabOrder.append(newTab) }
            tab = newTab
        } else if prefs.openOnCurrentActivity, let activityTab = tabForCurrentActivity() {
            tab = activityTab
        } else if !prefs.rememberLastTab {
            let preferred = prefs.defaultTab
            tab = visibleTabs.contains(preferred) ? preferred : (visibleTabs.first ?? .home)
        }
        wantsKeyboard = keyboard
        dismissAlert()
        isExpanded = true
        if keyboard { focusRequest = UUID() }
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        paletteOpen = false
        fileDragActive = false
        wantsKeyboard = false
        todo.commitCompleted()
    }

    private func tabForCurrentActivity() -> TabID? {
        if nowPlaying.hasMedia, nowPlaying.isPlaying, nowPlaying.allowsLiveActivity(sites: prefs.mediaAllowlist), prefs.tabOrder.contains(.nowPlaying) {
            return .nowPlaying
        }
        if timer.isRunning || timer.isActive, prefs.tabOrder.contains(.timer) {
            return .timer
        }
        return nil
    }

    func toggleIsland() { isExpanded ? collapse() : expand() }

    func toggle(tab target: TabID, keyboard: Bool = false) {
        if isExpanded, tab == target { collapse() } else { expand(tab: target, keyboard: keyboard) }
    }

    func openPalette() {
        expand(keyboard: true)
        paletteOpen = true
    }

    // MARK: Alerts

    func show(_ newAlert: IslandAlert) {
        guard !isExpanded else { return }
        alertWork?.cancel()
        alert = newAlert
        guard !newAlert.persistsUntilHover else { return }
        let work = DispatchWorkItem { [weak self] in
            guard self?.alert?.id == newAlert.id else { return }
            self?.alert = nil
        }
        alertWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + newAlert.duration, execute: work)
    }

    func dismissAlert() {
        alertWork?.cancel()
        alert = nil
    }

    func perform(_ action: AlertAction) {
        dismissAlert()
        switch action {
        case let .open(url): NSWorkspace.shared.open(url)
        case let .reveal(url): NSWorkspace.shared.activateFileViewerSelecting([url])
        case let .showTab(target): expand(tab: target)
        }
    }

    // MARK: Actions

    func toggleCaffeine() {
        caffeine.toggle(duration: prefs.caffeineDefault, keepDisplayOn: prefs.caffeineKeepsDisplayOn)
    }

    func startCaffeine(_ duration: CaffeineDuration) {
        caffeine.start(duration: duration, keepDisplayOn: prefs.caffeineKeepsDisplayOn)
    }

    func togglePomodoro() {
        if timer.mode != .pomodoro { timer.select(.pomodoro) }
        timer.toggle()
    }

    func addToShelf(_ urls: [URL]) {
        let count = shelf.add(urls)
        guard count > 0, !isExpanded else { return }
        show(IslandAlert(symbol: "tray.and.arrow.down.fill", tint: .teal, title: count == 1 ? "Added to Shelf" : "Added \(count) Files to Shelf", subtitle: urls.first?.lastPathComponent ?? "", actionTitle: "Open", action: .showTab(.shelf), duration: 3))
    }

    func airDrop(_ urls: [URL]) {
        shelf.airDrop(urls) { [weak self] sent in
            guard let self, sent, self.prefs.removeAfterAirDrop else { return }
            for item in self.shelf.items where urls.contains(item.url) { self.shelf.remove(item) }
        }
    }

    func pickColor() {
        collapse()
        SystemActions.pickColor { [weak self] hex in
            self?.colorPickerResult = hex
            self?.show(IslandAlert(symbol: "eyedropper.halffull", tint: Color(hex: hex) ?? .white, title: "Copied \(hex)", subtitle: "Color picked from the screen", duration: 2.5))
        }
    }

    var paletteCommands: [PaletteCommand] {
        var list: [PaletteCommand] = TabID.allCases.filter { $0 != .stats }.map { item in
            PaletteCommand(id: "tab.\(item.rawValue)", title: item.title, symbol: item.symbol, detail: "Tab") { [weak self] in
                self?.paletteOpen = false
                self?.expand(tab: item, keyboard: item == .todo || item == .clipboard)
            }
        }
        list += [
            PaletteCommand(id: "pomodoro", title: timer.isRunning ? "Pause Timer" : "Start Pomodoro", symbol: "timer", detail: display(.pomodoro)) { [weak self] in self?.togglePomodoro() },
            PaletteCommand(id: "caffeine", title: caffeine.isActive ? "Turn Off Caffeine" : "Turn On Caffeine", symbol: "cup.and.saucer.fill", detail: display(.caffeine)) { [weak self] in self?.toggleCaffeine() },
            PaletteCommand(id: "pin", title: pinned ? "Unpin the Island" : "Pin the Island", symbol: "pin.fill", detail: display(.pin)) { [weak self] in self?.pinned.toggle() },
            PaletteCommand(id: "play", title: nowPlaying.isPlaying ? "Pause Media" : "Play Media", symbol: "playpause.fill", detail: display(.playPause)) { [weak self] in self?.nowPlaying.playPause() },
            PaletteCommand(id: "next", title: "Next Track", symbol: "forward.fill") { [weak self] in self?.nowPlaying.next() },
            PaletteCommand(id: "screenshot", title: "Take Screenshot", symbol: "camera.viewfinder") { [weak self] in self?.collapse(); SystemActions.screenshot() },
            PaletteCommand(id: "color", title: "Pick a Color", symbol: "eyedropper") { [weak self] in self?.pickColor() },
            PaletteCommand(id: "airdrop", title: "AirDrop Shelf Files", symbol: "airplayaudio") { [weak self] in
                guard let self else { return }
                self.airDrop(self.shelf.items.map(\.url))
            },
            PaletteCommand(id: "clearclip", title: "Clear Clipboard History", symbol: "trash") { [weak self] in self?.clipboard.clearHistory() },
            PaletteCommand(id: "lock", title: "Turn Off Display", symbol: "lock.display") { SystemActions.lockScreen() },
            PaletteCommand(id: "settings", title: "Settings…", symbol: "gearshape", detail: display(.settings)) { [weak self] in self?.collapse(); self?.openSettings?() },
        ]
        return list
    }

    private func display(_ id: ShortcutID) -> String { prefs.shortcuts[id]?.display ?? "" }

    // MARK: Shortcuts

    func registerShortcuts() {
        var bindings: [(combo: KeyCombo, name: String, action: () -> Void)] = []
        for id in ShortcutID.allCases {
            guard let combo = prefs.shortcuts[id] else { continue }
            bindings.append((combo, id.title, { [weak self] in self?.runShortcut(id) }))
        }
        HotKeyCenter.shared.register(bindings)
        shortcutFailures = HotKeyCenter.shared.failures
        onShortcutsChanged?()
    }

    func suspendShortcuts() { HotKeyCenter.shared.unregisterAll() }

    func runShortcut(_ id: ShortcutID) {
        switch id {
        case .toggleIsland: toggleIsland()
        case .commandPalette: paletteOpen && isExpanded ? collapse() : openPalette()
        case .clipboard: toggle(tab: .clipboard, keyboard: true)
        case .dockClipboard: openDockClipboard?()
        case .todo: toggle(tab: .todo, keyboard: true)
        case .shelf: toggle(tab: .shelf)
        case .pomodoro:
            togglePomodoro()
            if !isExpanded {
                show(IslandAlert(symbol: "timer", tint: .orange, title: timer.isRunning ? "\(timer.phase.title) Started" : "Timer Paused", subtitle: "\(timer.display) remaining", duration: 2))
            }
        case .caffeine:
            toggleCaffeine()
            if !isExpanded {
                show(IslandAlert(symbol: "cup.and.saucer.fill", tint: .brown, title: caffeine.isActive ? "Caffeine On" : "Caffeine Off", subtitle: caffeine.isActive ? "Your Mac will stay awake" : "Normal sleep settings restored", duration: 2))
            }
        case .pin:
            pinned.toggle()
            if pinned { expand() }
        case .playPause: nowPlaying.playPause()
        case .settings: collapse(); openSettings?()
        }
    }

    // MARK: Preferences

    private func applyPreferences(previous: Preferences) {
        applyServiceSettings()
        if prefs.shortcuts != previous.shortcuts { registerShortcuts() }
        if prefs.launchAtLogin != previous.launchAtLogin, let message = LoginItem.set(prefs.launchAtLogin) {
            show(IslandAlert(symbol: "exclamationmark.triangle.fill", tint: .orange, title: "Couldn’t Change Open at Login", subtitle: message, duration: 5))
        }
        if prefs.screenshotsToShelf != previous.screenshotsToShelf {
            prefs.screenshotsToShelf ? screenshots.start() : screenshots.stop()
        }
        if tab == .stats || !visibleTabs.contains(tab), let first = visibleTabs.first { tab = first }
        recomputeActivity()
    }

    private func applyServiceSettings() {
        clipboard.enabled = prefs.clipboardHistory
        clipboard.limit = prefs.clipboardLimit
        clipboard.stripTrackers = prefs.stripLinkTrackers
        let persistChanged = clipboard.persistAll != prefs.clipboardPersist
        clipboard.persistAll = prefs.clipboardPersist
        if persistChanged { clipboard.persist() }
        timer.focusMinutes = prefs.focusMinutes
        timer.shortBreakMinutes = prefs.shortBreakMinutes
        timer.longBreakMinutes = prefs.longBreakMinutes
        timer.roundsBeforeLongBreak = prefs.roundsBeforeLongBreak
        timer.autoStartNext = prefs.autoStartNextPhase
        if todo.newestOnTop != prefs.todoNewestOnTop {
            todo.newestOnTop = prefs.todoNewestOnTop
            todo.objectWillChange.send()
        }
        if timer.mode == .pomodoro, !timer.isActive { timer.reset() }
    }

    // MARK: Events

    private func bindEvents() {
        let changes: [AnyPublisher<Void, Never>] = [
            nowPlaying.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            timer.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            downloads.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            caffeine.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            volume.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            brightness.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            battery.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(changes)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.recomputeActivity() }
            .store(in: &bag)

        nowPlaying.onTrackChange = { [weak self] title, artist in
            guard let self, self.prefs.trackChangePeek, self.prefs.mediaActivity, !self.isExpanded, self.nowPlaying.isPlaying else { return }
            guard self.nowPlaying.allowsLiveActivity(sites: self.prefs.mediaAllowlist) else { return }
            // An allowed website already has the live-activity pill. Don't also drop a track alert for it.
            if self.nowPlaying.isWebsite { return }
            let fields = [self.nowPlaying.title, self.nowPlaying.artist, self.nowPlaying.bundleID, self.nowPlaying.url, self.nowPlaying.pageURL]
            if MediaFilter.blocks(entries: self.prefs.mediaAllowlist, fields: fields) { return }
            self.show(IslandAlert(style: .track, symbol: "music.note", tint: self.nowPlaying.accent, title: title, subtitle: artist.isEmpty ? self.nowPlaying.appName : artist, duration: 3))
        }

        battery.onPowerChange = { [weak self] old, new in
            guard let self, new.hasBattery else { return }
            if self.prefs.chargingAlerts, new.isPluggedIn != old.isPluggedIn {
                if new.isPluggedIn {
                    let adapter = new.adapterWatts.map { " · \($0) W" } ?? ""
                    self.show(IslandAlert(symbol: "battery.100percent.bolt", tint: .green, title: "Charging · \(new.percent)%", subtitle: new.timeDescription + adapter, duration: 3.5))
                } else {
                    self.show(IslandAlert(symbol: "battery.75percent", tint: .white, title: "On Battery · \(new.percent)%", subtitle: new.timeDescription, duration: 3))
                }
            }
            if self.prefs.chargingAlerts, new.isFull, !old.isFull, new.isPluggedIn {
                self.show(IslandAlert(symbol: "battery.100percent", tint: .green, title: "Fully Charged", subtitle: "You can unplug your Mac", duration: 3.5))
            }
            if self.prefs.lowBatteryAlert, !new.isPluggedIn, [20, 10, 5].contains(where: { new.percent <= $0 && old.percent > $0 }) {
                self.show(IslandAlert(symbol: "battery.25percent", tint: .red, title: "Low Battery · \(new.percent)%", subtitle: new.timeDescription, duration: 6))
            }
        }

        timer.onPhaseEnd = { [weak self] title, subtitle in
            guard let self else { return }
            if self.prefs.timerSound { self.playTimerChime() }
            self.show(IslandAlert(symbol: "timer", tint: .orange, title: title, subtitle: subtitle, actionTitle: "Open", action: .showTab(.timer), persistsUntilHover: true))
        }

        downloads.onFinished = { [weak self] url in
            guard let self, self.prefs.downloadActivity else { return }
            if self.prefs.downloadsToShelf { self.shelf.add([url]) }
            let shelved = self.prefs.downloadsToShelf
            self.show(IslandAlert(
                symbol: "arrow.down.circle.fill",
                tint: .blue,
                title: shelved ? "Saved to Shelf" : "Download Ready",
                subtitle: url.lastPathComponent,
                actionTitle: "Reveal",
                action: .reveal(url),
                duration: 8
            ))
        }

        screenshots.onScreenshot = { [weak self] url in
            // Give screencapture a moment to finish writing the file.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self?.addToShelf([url]) }
        }
    }

    private func everySecond() {
        nowPlaying.expireArtworkIfNeeded()
        shelf.prune(lifetime: prefs.shelfLifetime)
        timer.rollPomodoroDayIfNeeded()
        recomputeActivity()
        checkEventAlerts()
    }

    /// Three separate rings. The named system sound is one shared object, so replaying it only restarts the same chime.
    private func playTimerChime() {
        chimePlayer.play(times: 3)
    }

    private func checkEventAlerts() {
        guard prefs.eventAlerts, !isExpanded else { return }
        let lead = TimeInterval(prefs.eventAlertMinutes * 60)
        for event in calendar.upcoming {
            let until = event.start.timeIntervalSinceNow
            let key = "\(event.id)|\(event.start.timeIntervalSince1970)"
            if until > 0, until <= lead, !alertedEvents.contains(key) {
                alertedEvents.insert(key)
                let minutes = max(1, Int((until / 60).rounded()))
                show(IslandAlert(
                    symbol: event.joinURL == nil ? "calendar" : "video.fill",
                    tint: event.color,
                    title: event.title,
                    subtitle: "Starts in \(minutes) min · \(event.start.formatted(date: .omitted, time: .shortened))",
                    actionTitle: event.joinURL == nil ? "Open" : "Join",
                    action: event.joinURL.map { .open($0) } ?? .showTab(.calendar),
                    duration: 12
                ))
                break
            }
        }
    }

    private func recomputeActivity() {
        let next = resolveActivity()
        if next != activity {
            activity = next
        }
    }

    private func resolveActivity() -> LiveActivity? {
        if prefs.downloadActivity, downloads.primary != nil { return .download }
        if prefs.timerActivity, timer.isRunning || (timer.isActive && timer.mode != .stopwatch) { return .timer }
        if prefs.alwaysShowNowPlaying, nowPlaying.hasMedia, nowPlaying.allowsLiveActivity(sites: prefs.mediaAllowlist),
           nowPlaying.isPlaying || Date().timeIntervalSince(nowPlaying.lastChange) < prefs.keepPausedMediaSeconds
        {
            return .media
        }
        if prefs.caffeineActivity, caffeine.isActive { return .caffeine }
        if battery.vitals.isCharging, prefs.chargingAlerts { return .charging }
        return nil
    }

    func playClipboardSound() {
        guard prefs.clipboardSound != .none else { return }
        playSound(named: prefs.clipboardSound.rawValue)
    }

    /// Copies as plain text onto the system clipboard and plays a confirmation.
    func pastePlainText(_ text: String) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
        clipboard.noteExternalChange()
        playPopSound()
    }

    func playPopSound() {
        playSound(named: "pop")
    }

    func playTodoAddedSound() {
        playSound(named: "wow")
    }

    func playTodoCompleteSound() {
        playSound(named: "todo")
    }

    private func playSound(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds") else { return }
        NSSound(contentsOf: url, byReference: true)?.play()
    }

    /// Slot 1 is the newest copy. Puts it on the system clipboard.
    func pasteClipboard(slot: Int) {
        let items = clipboard.filtered
        guard (1 ... 9).contains(slot), slot <= items.count else { return }
        clipboard.copy(items[slot - 1])
        playPopSound()
        collapse()
    }
}

/// Plays the Glass alert as separate rings. `NSSound(named:)` returns one shared sound, so a second play only restarts it.
private final class ChimePlayer: NSObject, NSSoundDelegate {
    private var remaining = 0
    private var current: NSSound?
    private var generation = 0

    func play(times: Int) {
        generation += 1
        remaining = times
        current?.stop()
        current = nil
        ring(generation)
    }

    private func ring(_ generation: Int) {
        guard generation == self.generation, remaining > 0 else { return }
        remaining -= 1
        let url = URL(fileURLWithPath: "/System/Library/Sounds/Glass.aiff")
        guard let sound = NSSound(contentsOf: url, byReference: false) else { return }
        sound.delegate = self
        current = sound
        sound.play()
        let gap = max(sound.duration, 1.65) + 0.2
        DispatchQueue.main.asyncAfter(deadline: .now() + gap) { [weak self] in
            self?.advance(generation, sound: sound)
        }
    }

    func sound(_ sound: NSSound, didFinishPlaying finished: Bool) {
        guard finished else { return }
        let generation = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.advance(generation, sound: sound)
        }
    }

    private func advance(_ generation: Int, sound: NSSound) {
        guard generation == self.generation, current === sound else { return }
        current = nil
        ring(generation)
    }
}

extension Color {
    init?(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        self.init(red: Double((number >> 16) & 0xFF) / 255, green: Double((number >> 8) & 0xFF) / 255, blue: Double(number & 0xFF) / 255)
    }
}
