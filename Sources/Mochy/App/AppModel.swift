import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var islandState: IslandState = .collapsed
    @Published var selectedTab: TabID = .home
    @Published var enabledTabs: Set<TabID>
    @Published var enabledOverlays: Set<OverlayID>
    @Published var transient: TransientIsland?
    @Published var settingsOpen = false
    @Published var settingsPage: SettingsPage = .general
    @Published var paletteOpen = false
    @Published var prefs: Preferences
    @Published var hidden = false
    var tools = CaptureTools()
    var hud = HUDController()
    var keycaps = KeycapHUD()
    var lastCommandC: Date?
    private var cancellables = Set<AnyCancellable>()
    private var lastCountdown = Date.distantPast
    private var lastStand = Date()
    private var lastWater = Date()
    private var lastLook = Date()

    var petOpen: Bool {
        get { prefs.petOnDesktop }
        set { prefs.petOnDesktop = newValue }
    }
    var hideNotchBezel: Bool {
        get { prefs.hideNotchBezel }
        set { prefs.hideNotchBezel = newValue }
    }
    var apiToken: String {
        get { prefs.apiToken }
        set { prefs.apiToken = newValue }
    }
    var apiPort: Int {
        get { prefs.apiPort }
        set { prefs.apiPort = newValue }
    }
    var apiEnabled: Bool {
        get { prefs.apiEnabled }
        set { prefs.apiEnabled = newValue }
    }
    var homeCards: [HomeCard] {
        get { prefs.homeCards }
        set { prefs.homeCards = newValue }
    }

    var battery = BatteryService()
    var caffeine = CaffeineService()
    var bluetooth = BluetoothService()
    var weather = WeatherService()
    var input = InputMonitor()
    var folders = FolderWatcher()
    var clipboard = ClipboardService()
    var nowPlaying = NowPlayingService()
    var mixer = SoundMixerService()
    var songID = SongIDService()
    var typing = TypingSoundService()
    var dictation = DictationService()
    var calendar = CalendarService()
    var timer = TimerService()
    var calculator = CalculatorService()
    var notes = NotesService()
    var translate = TranslateService()
    var activity = ActivityService()
    var aiUsage = AIUsageService()
    var askAI = AskAIService()
    var stocks = StocksService()
    var launcher = LauncherService()
    var terminal = TerminalService()
    var packages = PackagesService()
    var focus = FocusService()
    var inbox = NotificationInbox()
    var shelf = ShelfService()
    var pet = PetManager()

    private var ticks: AnyCancellable?
    private var lastLowAlert = Date.distantPast
    private var lastCaps = false

    init() {
        let loaded = Preferences.load()
        prefs = loaded
        let storedTabs = loaded.enabledTabs.compactMap(TabID.init(rawValue:))
        enabledTabs = storedTabs.isEmpty ? TabID.defaultEnabled : Set(storedTabs)
        enabledOverlays = Set(loaded.enabledOverlays.compactMap(OverlayID.init(rawValue:)))
        if enabledOverlays.isEmpty { enabledOverlays = Set(OverlayID.allCases) }
        notes.load()
        shelf.load()
        launcher.load()
        aiUsage.refresh()
        calendar.request()
        folders.start()
        input.start()
        weather.request()
        typing.enabled = prefs.typingSounds
        typing.profile = prefs.typingProfile
        askAI.apiKey = prefs.anthropicKey
        timer.focusMinutes = prefs.pomodoroFocus
        timer.breakMinutes = prefs.pomodoroBreak
        bind()
        hud.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        keycaps.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        tools.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        ticks = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.tick()
        }
    }

    var visibleTabs: [TabID] {
        TabID.allCases.filter { enabledTabs.contains($0) }
    }

    func persist() {
        prefs.enabledTabs = enabledTabs.map(\.rawValue)
        prefs.enabledOverlays = enabledOverlays.map(\.rawValue)
        prefs.save()
    }

    func expand(tab: TabID? = nil) {
        hidden = false
        if let tab, enabledTabs.contains(tab) {
            selectedTab = tab
        } else if islandState == .collapsed, let fallback = TabID(rawValue: prefs.defaultTab), enabledTabs.contains(fallback) {
            selectedTab = fallback
        }
        islandState = .expanded
    }

    func collapse() {
        islandState = .collapsed
        paletteOpen = false
    }

    func showIsland(title: String, message: String, symbol: String, tint: String = "mint", duration: TimeInterval = 3.4) {
        transient = TransientIsland(title: title, message: message, symbol: symbol, tintName: tint, duration: min(10, max(1, duration)))
        islandState = .transient
        let hold = transient?.id
        DispatchQueue.main.asyncAfter(deadline: .now() + (transient?.duration ?? 3)) { [weak self] in
            guard self?.transient?.id == hold else { return }
            self?.transient = nil
            if self?.islandState == .transient {
                self?.islandState = .collapsed
            }
        }
    }

    func handleURL(_ url: URL) {
        guard url.scheme == "mochy" else { return }
        if url.host == "show" || url.path.contains("show") {
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            let title = items?.first(where: { $0.name == "title" })?.value ?? "Mochy"
            let message = items?.first(where: { $0.name == "message" })?.value ?? ""
            let duration = Double(items?.first(where: { $0.name == "duration" })?.value ?? "3") ?? 3
            showIsland(title: String(title.prefix(120)), message: String(message.prefix(500)), symbol: "bell.fill", duration: duration)
        } else if url.host == "expand" {
            expand()
        } else if url.host == "lock" {
            lockScreen()
        } else if url.host == "screenshot" {
            captureScreenshot()
        } else if url.host == "caffeine" {
            caffeine.toggle()
        } else if url.host == "hide" {
            hidden = true
            collapse()
        }
    }

    func captureScreenshot() {
        let dest = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mochy Screenshot \(Int(Date().timeIntervalSince1970)).png")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-i", dest.path]
        try? task.run()
        showIsland(title: "Capture Screenshot", message: "Select an area", symbol: "camera.viewfinder")
    }

    func lockScreen() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession")
        if FileManager.default.isExecutableFile(atPath: task.executableURL!.path) {
            task.arguments = ["-suspend"]
            try? task.run()
        } else {
            let alt = Process()
            alt.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            alt.arguments = ["displaysleepnow"]
            try? alt.run()
        }
        showIsland(title: "Lock Screen", message: "Display locked", symbol: "lock.fill")
    }

    func factoryReset() {
        var fresh = Preferences()
        fresh.apiToken = prefs.apiToken
        prefs = fresh
        enabledTabs = TabID.defaultEnabled
        enabledOverlays = Set(OverlayID.allCases)
        notes.draft = ""
        notes.save()
        clipboard.items = []
        persist()
        showIsland(title: "Reset", message: "Preferences restored to defaults", symbol: "arrow.counterclockwise")
    }

    private func bind() {
        battery.onChargingChange = { [weak self] charging, percent in
            guard let self, self.prefs.chargingIsland, self.enabledOverlays.contains(.charging) else { return }
            if charging {
                self.showIsland(title: "Charging", message: "\(percent)% · \(self.battery.timeRemaining)", symbol: "battery.100.bolt", tint: "green")
            } else {
                self.showIsland(title: "On Battery", message: "\(percent)% remaining", symbol: "battery.75", tint: "orange")
            }
        }
        battery.onLowBattery = { [weak self] percent in
            guard let self, self.prefs.lowBatteryIsland, self.enabledOverlays.contains(.lowBattery) else { return }
            guard Date().timeIntervalSince(self.lastLowAlert) > 120 else { return }
            self.lastLowAlert = Date()
            self.showIsland(title: "Battery Low", message: "Battery at \(percent)%. Plug in?", symbol: "battery.25", tint: "red")
        }
        nowPlaying.onSongChange = { [weak self] title, artist in
            guard let self, self.prefs.songChangeIsland, self.enabledOverlays.contains(.nowPlayingChange) else { return }
            self.showIsland(title: title, message: artist, symbol: "music.note")
        }
        folders.onDownload = { [weak self] url in
            guard let self, self.enabledOverlays.contains(.download) else { return }
            self.shelf.add(url)
            self.showIsland(title: "Download", message: url.lastPathComponent, symbol: "arrow.down.circle.fill", tint: "blue")
        }
        folders.onScreenshot = { [weak self] url in
            guard let self, self.prefs.screenshotIsland, self.enabledOverlays.contains(.screenshot) else { return }
            self.shelf.add(url)
            self.showIsland(title: "Screenshot", message: url.lastPathComponent, symbol: "camera.viewfinder")
        }
        input.onCapsLock = { [weak self] on in
            guard let self, self.prefs.capsLockHUD, self.enabledOverlays.contains(.capsLock) else { return }
            self.showIsland(title: on ? "Caps Lock On" : "Caps Lock Off", message: on ? "A quick island so you know which way it went" : "Back to lowercase", symbol: "capslock.fill")
        }
        input.onVolumeKey = { [weak self] volume in
            guard let self, self.prefs.volumeHUD else { return }
            if self.prefs.hideVolumeHUDDuringFocus, self.focus.sessionActive { return }
            self.mixer.systemVolume = volume
            if self.prefs.replaceSystemHUD {
                self.hud.show(title: "Volume", value: volume, symbol: volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
            } else {
                self.showIsland(title: "Volume", message: "\(volume)%", symbol: volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill", duration: 1.4)
            }
        }
        input.onBrightnessKey = { [weak self] value in
            guard let self, self.prefs.brightnessOverlay else { return }
            if self.prefs.hideVolumeHUDDuringFocus, self.focus.sessionActive { return }
            if self.prefs.replaceSystemHUD {
                self.hud.show(title: "Brightness", value: value, symbol: "sun.max.fill")
            } else {
                self.showIsland(title: "Brightness", message: "\(value)%", symbol: "sun.max.fill", duration: 1.4)
            }
        }
        input.onKey = { [weak self] code, event in
            guard let self else { return }
            if self.prefs.typingSounds { self.typing.tap() }
            self.activity.keystroke()
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if self.prefs.keycapHUD {
                let hasMod = mods.contains(.command) || mods.contains(.option) || mods.contains(.control)
                if hasMod || !self.prefs.onlyModifierCombos {
                    self.keycaps.show(Self.describeKey(code: code, flags: mods))
                }
            }
            if code == 8, mods.contains(.command), !mods.contains(.shift), !mods.contains(.option) {
                let now = Date()
                if let last = self.lastCommandC, now.timeIntervalSince(last) < 0.45, self.prefs.twoCommandCOpensHistory {
                    self.enabledTabs.insert(.clipboard)
                    self.expand(tab: .clipboard)
                }
                self.lastCommandC = now
            }
        }
        timer.onDone = { [weak self] message in
            guard let self, self.prefs.timerAlerts, self.enabledOverlays.contains(.timerDone) else { return }
            NSSound.beep()
            self.showIsland(title: message, message: "Timer finished", symbol: "timer", tint: "orange")
        }
    }

    private func tick() {
        battery.refresh()
        nowPlaying.refresh()
        mixer.refresh()
        if prefs.clipboardCapture {
            let before = clipboard.items.first?.text
            clipboard.poll(limit: prefs.historyLimit)
            if prefs.stripTrackers, let newest = clipboard.items.first, newest.text != before, newest.text.contains("http") {
                let cleaned = tools.stripTrackers(newest.text)
                if cleaned != newest.text { clipboard.copy(cleaned) }
            }
            if prefs.clipboardCaptureSound, clipboard.items.first?.text != before {
                NSSound.beep()
            }
        }
        if prefs.autoClearClipboard, let first = clipboard.items.first,
           Date().timeIntervalSince(first.date) > prefs.autoClearSeconds {
            clipboard.items = []
            NSPasteboard.general.clearContents()
        }
        bluetooth.refresh()
        timer.focusMinutes = prefs.pomodoroFocus
        timer.breakMinutes = prefs.pomodoroBreak
        timer.tick()
        pet.tick(playing: nowPlaying.isPlaying, charging: battery.isCharging)
        if weather.temperature == "—" { weather.request() }
        tickCalendarCountdown()
        tickReminders()
        typing.enabled = prefs.typingSounds
        typing.profile = prefs.typingProfile
        askAI.apiKey = prefs.anthropicKey
    }

    private func tickCalendarCountdown() {
        guard prefs.countdownIsland, let next = calendar.nextEvent else { return }
        let minutes = next.start.timeIntervalSinceNow / 60
        guard minutes > 0, minutes <= Double(prefs.countdownMinutes) else { return }
        guard Date().timeIntervalSince(lastCountdown) > 60 else { return }
        lastCountdown = Date()
        showIsland(title: next.title, message: "Starts in \(Int(minutes)) min", symbol: "calendar", tint: "orange")
    }

    private func tickReminders() {
        guard prefs.breakReminders else { return }
        let hour: TimeInterval = 60 * 60
        if prefs.standReminder, Date().timeIntervalSince(lastStand) > hour {
            lastStand = Date()
            showIsland(title: "Stand up", message: "A reminder to get up and move", symbol: "figure.stand", tint: "green")
        }
        if prefs.waterReminder, Date().timeIntervalSince(lastWater) > hour * 1.5 {
            lastWater = Date()
            showIsland(title: "Water", message: "A reminder to take a water break", symbol: "drop.fill", tint: "blue")
        }
        if prefs.lookAwayReminder, Date().timeIntervalSince(lastLook) > 20 * 60 {
            lastLook = Date()
            showIsland(title: "Look away", message: "A reminder to look away from the screen", symbol: "eye", tint: "mint")
        }
    }

    func performShortcut(_ action: ShortcutAction) {
        switch action.id {
        case "palette":
            paletteOpen = true
            expand()
        case "settings":
            settingsOpen = true
        case "clipboard":
            enabledTabs.insert(.clipboard)
            expand(tab: .clipboard)
        case "open":
            hidden = false
            expand()
        case "hide":
            hidden = true
            collapse()
        case "pastePlain":
            tools.pastePlain()
            showIsland(title: "Paste as Plain Text", message: "Formatting stripped", symbol: "doc.plaintext")
        case "typing":
            prefs.typingSounds.toggle()
            typing.enabled = prefs.typingSounds
        case "pomodoro":
            enabledTabs.insert(.timer)
            timer.mode = .pomodoro
            timer.reset()
            timer.toggle()
            expand(tab: .timer)
        case "emergency":
            exit(0)
        default:
            break
        }
    }

    static func describeKey(code: UInt16, flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        let names: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 5: "G", 4: "H", 38: "J", 40: "K", 37: "L",
            12: "Q", 13: "W", 14: "E", 15: "R", 17: "T", 16: "Y", 32: "U", 34: "I", 31: "O", 35: "P",
            6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 45: "N", 46: "M",
            49: "Space", 36: "Return", 53: "Esc", 48: "Tab", 51: "Delete", 43: ",",
        ]
        parts.append(names[code] ?? "Key \(code)")
        return parts.joined()
    }

    static func matches(_ combo: KeyCombo, event: NSEvent) -> Bool {
        guard combo.enabled, combo.keyCode != 0 else { return false }
        guard event.keyCode == combo.keyCode else { return false }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var need: NSEvent.ModifierFlags = []
        if combo.modifiers & 1 != 0 { need.insert(.control) }
        if combo.modifiers & 2 != 0 { need.insert(.option) }
        if combo.modifiers & 4 != 0 { need.insert(.shift) }
        if combo.modifiers & 8 != 0 { need.insert(.command) }
        let relevant = mods.intersection([.control, .option, .shift, .command])
        return relevant == need
    }
}
