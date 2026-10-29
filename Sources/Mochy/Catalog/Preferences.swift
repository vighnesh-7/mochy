import Foundation
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable, Hashable {
    case general, appearance, behavior, displays, tabs, home, permissions
    case battery, caffeine, calendar, nowPlaying, capture, clipboard
    case notifications, calls, faceUnlock, lockScreen, typing, pointer
    case cuely, timer, activity, aiUsage, pet, connectivity, terminal
    case quickSearch, stocks, spaces, knock, widgets, developer, gallery, about

    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .behavior: "Behavior"
        case .displays: "Displays"
        case .tabs: "Tabs"
        case .home: "Home"
        case .permissions: "Permissions"
        case .battery: "Battery & Fans"
        case .caffeine: "Caffeine"
        case .calendar: "Calendar"
        case .nowPlaying: "Now Playing"
        case .capture: "Capture"
        case .clipboard: "Clipboard"
        case .notifications: "Notifications"
        case .calls: "Calls & Messages"
        case .faceUnlock: "Face Unlock"
        case .lockScreen: "Lock Screen"
        case .typing: "Typing Sounds"
        case .pointer: "Pointer"
        case .cuely: "Cuely"
        case .timer: "Timer"
        case .activity: "Activity"
        case .aiUsage: "AI Usage"
        case .pet: "Desktop Pet"
        case .connectivity: "Connectivity"
        case .terminal: "Terminal"
        case .quickSearch: "Quick Search"
        case .stocks: "Stocks"
        case .spaces: "Spaces"
        case .knock: "Knock"
        case .widgets: "Widgets"
        case .developer: "Developer"
        case .gallery: "All Tools"
        case .about: "About"
        }
    }
}

struct KeyCombo: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt // control=1 option=2 shift=4 command=8
    var enabled: Bool
    var display: String
    static let palette = KeyCombo(keyCode: 40, modifiers: 3, enabled: true, display: "⌃⌥K")
    static let clipboard = KeyCombo(keyCode: 8, modifiers: 3, enabled: true, display: "⌃⌥C")
    static let settings = KeyCombo(keyCode: 43, modifiers: 8, enabled: true, display: "⌘,")
    static let emergency = KeyCombo(keyCode: 53, modifiers: 11, enabled: true, display: "⌃⌥⌘⎋")
    static func empty(_ name: String) -> KeyCombo { KeyCombo(keyCode: 0, modifiers: 0, enabled: false, display: name) }
}

struct Preferences: Codable, Equatable {
    // MARK: General
    var launchAtLogin = false
    var language = "system"
    var clock24h = false
    var showMenuBarIcon = true
    var batteryInMenuBar = false
    var nextMeetingInMenuBar = false
    var hideMenuBarIcons = false
    var revealHiddenIconsOnHover = true
    var hideWhenColliding = true
    var hideFromZoomMeetTeamsOBS = false
    var detectLanguage = true
    var helloIntro = true
    var menuBarReadout = "time"
    var defaultTab = "home"
    var expandOnHover = true
    var hoverDelay: Double = 0.12
    var hoverToOpen = true
    var autoCollapse = true
    var collapseDelay: Double = 0.55
    var commandPaletteButton = true
    var hideMochyShortcut = KeyCombo.empty("Hide Mochy")
    var openMochyShortcut = KeyCombo.empty("Open Mochy")
    var commandPaletteShortcut = KeyCombo.palette
    var settingsShortcut = KeyCombo.settings

    // MARK: Appearance
    var glassLook = "Glass"
    var liquidGlass = true
    var monochromeGlass = false
    var adaptToAppearance = true
    var whiteAccents = false
    var fontFamily = "System"
    var fontSize: Double = 13
    var panelFontSize: Double = 13
    var closedPillWidth: Double = 280
    var closedPillHeight: Double = 34
    var idlePillSize: Double = 34
    var panelWidth: Double = 640
    var panelHeight: Double = 320
    var glassOpacity: Double = 0.55
    var glassRimBrightness: Double = 0.5
    var hudStyle = "Pill"
    var hudSize: Double = 1.0
    var hudWidth: Double = 360
    var circularHUD = false
    var blackOutCorners = false
    var hideNotchBezel = false
    var fadeIslandToGlass = true
    var notchShape = "Notch"
    var animationSpeed: Double = 1.0
    var animationStyle = "Spring"
    var matchReduceMotion = true
    var colorCodedBattery = true
    var colorCodedVolume = true

    // MARK: Behavior
    var requireDoubleClick = false
    var peekOnHover = true
    var musicPeek = true
    var timerPeek = true
    var swipeGestures = true
    var swipeToChangeTabs = true
    var swipeToChangeTrack = true
    var swipeToDismiss = true
    var swipeToOpen = true
    var doubleTapModifier = false
    var hoverDamping: Double = 0.8
    var hoverResponse = "Snappy"
    var showUnlockAnimation = true
    var invisibleUntilHover = false

    // MARK: Displays
    var showOnAllDisplays = true
    var onlyDisplayWithPointer = false
    var hidePillWhileMirrored = true
    var brightnessOverlay = true
    var replaceSystemHUD = true
    var brightnessKeysControlExternal = false
    var extraDim = false
    var extraBrightness = false
    var quietBrightnessDuringFocus = true
    var hudOnKeyboardBacklight = true
    var hideVolumeHUDDuringFocus = true

    // MARK: Home
    var homeColumns = 2
    var compactHome = false
    var weatherOnHome = true
    var weatherUnits = "C"
    var quickActions: [String] = ["screenshot", "caffeine", "lock", "record", "color", "qr"]

    // MARK: Battery
    var chargingIsland = true
    var lowBatteryIsland = true
    var batteryDrainWarnings = true
    var accessoryAlerts = true
    var accessoryAlertLevel = 10
    var accessoryFullyChargedIsland = true
    var hideMacOSBatteryAlerts = true
    var chargeLimitEnabled = false
    var chargeLimitPercent = 80
    var fanControl = false
    var caffeineButton = true
    var caffeineNotifications = true
    var stopwatchNextToCaffeine = true
    var notifyLowPowerMode = true
    var lowPowerPauseAnimations = true

    // MARK: Calendar
    var countdownIsland = true
    var countdownMinutes = 5
    var joinButton = true
    var calendarCapture = false
    var naturalLanguageReminderDates = true
    var skipEventsWithoutVideo = false
    var nextMeetingInPill = true

    // MARK: Now Playing
    var lyricsOnPill = true
    var syncedLyrics = true
    var lyricsInNowPlaying = true
    var desktopLyrics = false
    var fullScreenLyrics = false
    var mediaKeys = true
    var announceNewTracks = false
    var alwaysShowTrackInfo = false
    var audioReactiveBars = true
    var appVolumeMixer = true
    var equalizerEnabled = false
    var spotifyClientID = ""
    var controlPlaybackWithMediaKeys = true
    var songChangeIsland = true

    // MARK: Capture
    var screenshotToShelf = true
    var annotateAfterCapture = false
    var watermark = false
    var watermarkText = "Mochy"
    var watermarkOpacity: Double = 0.35
    var scrollingScreenshot = true
    var ocrScreenshots = true
    var keepPillOutOfCaptures = true
    var colorPickerButton = true
    var qrButton = true
    var recordButton = true
    var screenshotIsland = true
    var hidePersonalInfo = false

    // MARK: Clipboard
    var clipboardCapture = true
    var clipboardCaptureSound = false
    var twoCommandCOpensHistory = true
    var clipboardShortcut = KeyCombo.clipboard
    var pastePlainShortcut = KeyCombo.empty("Paste as Plain Text")
    var autoClearClipboard = false
    var autoClearSeconds = 60.0
    var stripTrackers = true
    var clipboardSnippets: [String] = []
    var historyLimit = 50

    // MARK: Notifications
    var mirrorAppNotifications = true
    var expandNotificationsOnHover = true
    var fullSizeNotifications = false
    var notificationDuration: Double = 4
    var keepMacOSBanner = false
    var notificationsOnlyMode = false
    var showAfterNativeBanner = false

    // MARK: Calls
    var callIslands = true
    var callerPhotos = true
    var messageReply = true
    var hideFromMeetingCaptures = false

    // MARK: Face Unlock / Lock / Camera
    var faceUnlock = false
    var faceUnlockEnrolled = false
    var cameraGuard = false
    var cameraIsland = true
    var lockScreenWidget = false
    var lockUnlockPill = true

    // MARK: Typing / Pointer
    var typingSounds = false
    var typingProfile = "Cream"
    var pauseTypingShortcut = KeyCombo.empty("Pause Typing Sounds")
    var keycapHUD = false
    var onlyModifierCombos = true
    var clickRipples = false
    var pointerTrail = false
    var pointerHalo = false
    var spotlightOnControlOption = false
    var cleanKeyboard = false

    // MARK: Cuely
    var cuelyAutoScroll = true
    var cuelyFollowVoice = false
    var cuelyFontSize: Double = 22
    var cuelyOpacity: Double = 1
    var cuelyScrollSpeed: Double = 1

    // MARK: Timer / Activity
    var pomodoroFocus = 25.0
    var pomodoroBreak = 5.0
    var pomodoroShortcut = KeyCombo.empty("Start Pomodoro")
    var timerAlerts = true
    var breakReminders = true
    var standReminder = true
    var waterReminder = true
    var lookAwayReminder = true
    var activityRings = true
    var activityOrb = false
    var blockAppsWhileFocusing = false

    // MARK: AI
    var agentPermissionIslands = true
    var aiUsageAlerts = true
    var aiNotificationSounds = false
    var anthropicKey = ""

    // MARK: Pet
    var petOnDesktop = true
    var petVisitsOtherDisplays = false
    var petBedtime = true
    var petHidesDuringFocus = true

    // MARK: Connectivity
    var airPodsIslands = true
    var autodetectAirPods = true
    var connectivityIslands = true
    var capsLockHUD = true
    var volumeHUD = true

    // MARK: Terminal / Search / Stocks / Spaces / Knock / Widgets
    var nerdFont = false
    var searchEngines: [String] = ["Google", "YouTube", "GitHub", "DuckDuckGo"]
    var spacesPills = true
    var spaceNameIsland = true
    var knockEnabled = false
    var desktopWidgets = false
    var widgetGlass = true
    var clockWidget = true
    var worldClockWidget = false
    var weatherWidget = true
    var photoWidget = false

    // MARK: Developer
    var apiEnabled = true
    var apiPort = 9999
    var apiToken = ""
    var anonymousAnalytics = false
    var autoRestartIfFrozen = true
    var emergencyShortcut = KeyCombo.emergency

    // MARK: Overlays master
    var enabledOverlays: [String] = OverlayID.allCases.map(\.rawValue)
    var enabledTabs: [String] = TabID.defaultEnabled.map(\.rawValue)
    var homeCards: [HomeCard] = [
        HomeCard(id: "nowPlaying", title: "Now Playing", symbol: "music.note", enabled: true),
        HomeCard(id: "weather", title: "Weather", symbol: "cloud.sun.fill", enabled: true),
        HomeCard(id: "battery", title: "Battery", symbol: "battery.100", enabled: true),
        HomeCard(id: "calendar", title: "Up Next", symbol: "calendar", enabled: true),
        HomeCard(id: "pet", title: "Mochi", symbol: "pawprint.fill", enabled: true),
        HomeCard(id: "timer", title: "Timer", symbol: "timer", enabled: true),
        HomeCard(id: "focus", title: "Focus", symbol: "moon.fill", enabled: false),
        HomeCard(id: "stocks", title: "Stocks", symbol: "chart.line.uptrend.xyaxis", enabled: false),
        HomeCard(id: "clipboard", title: "Clipboard", symbol: "doc.on.clipboard", enabled: false),
        HomeCard(id: "shortcuts", title: "Shortcuts", symbol: "square.stack.3d.up.fill", enabled: false),
    ]

    static let storageKey = "mochy.preferences.v2"

    static func load() -> Preferences {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(Preferences.self, from: data)
        else {
            var p = Preferences()
            p.apiToken = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24)).lowercased()
            p.save()
            return p
        }
        return decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

struct ShortcutAction: Identifiable {
    let id: String
    let title: String
    let detail: String
    var keyPath: WritableKeyPath<Preferences, KeyCombo>
}

enum ShortcutCatalog {
    static let all: [ShortcutAction] = [
        .init(id: "palette", title: "Command Palette", detail: "Press ⌃⌥K anywhere for the command palette", keyPath: \.commandPaletteShortcut),
        .init(id: "settings", title: "Open Settings", detail: "Right-click the pill (or ⌘,) opens Settings either way", keyPath: \.settingsShortcut),
        .init(id: "clipboard", title: "Open Clipboard History", detail: "Notchy remembers your clipboard — ⌃⌥C opens history", keyPath: \.clipboardShortcut),
        .init(id: "open", title: "Open Mochy", detail: "Activates Mochy so you can type", keyPath: \.openMochyShortcut),
        .init(id: "hide", title: "Hide Mochy", detail: "Hide the pill until summoned", keyPath: \.hideMochyShortcut),
        .init(id: "pastePlain", title: "Paste as Plain Text", detail: "Strip formatting for one paste, then restore the clipboard", keyPath: \.pastePlainShortcut),
        .init(id: "typing", title: "Pause Typing Sounds", detail: "A shortcut to pause it", keyPath: \.pauseTypingShortcut),
        .init(id: "pomodoro", title: "Start Pomodoro", detail: "One click starts focus", keyPath: \.pomodoroShortcut),
        .init(id: "emergency", title: "Emergency Quit", detail: "If Mochy ever freezes, ⌃⌥⌘⎋ force-quits it instantly", keyPath: \.emergencyShortcut),
    ]
}
