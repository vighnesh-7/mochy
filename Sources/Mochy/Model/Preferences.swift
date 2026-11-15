import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation
import SwiftUI

enum TabID: String, CaseIterable, Identifiable, Codable {
    case home, nowPlaying, shelf, clipboard, todo, timer, calendar, stats
    case notes, calculator, quickSearch, launcher, emoji, mirror

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .nowPlaying: "Now Playing"
        case .shelf: "Shelf"
        case .clipboard: "Clipboard"
        case .todo: "To-Do"
        case .timer: "Pomodoro"
        case .calendar: "Calendar"
        case .stats: "System"
        case .notes: "Notes"
        case .calculator: "Calculator"
        case .quickSearch: "Search"
        case .launcher: "Launcher"
        case .emoji: "Emoji"
        case .mirror: "Mirror"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .nowPlaying: "play.circle.fill"
        case .shelf: "tray.full.fill"
        case .clipboard: "doc.on.clipboard.fill"
        case .todo: "checklist"
        case .timer: "timer"
        case .calendar: "calendar"
        case .stats: "cpu.fill"
        case .notes: "note.text"
        case .calculator: "plus.forwardslash.minus"
        case .quickSearch: "magnifyingglass"
        case .launcher: "square.grid.3x3.fill"
        case .emoji: "face.smiling.inverse"
        case .mirror: "web.camera.fill"
        }
    }

    var summary: String {
        switch self {
        case .home: "Now playing, today’s events and quick controls."
        case .nowPlaying: "The track or video playing on this Mac."
        case .shelf: "Park files in the notch, drag them out, or AirDrop them."
        case .clipboard: "Recent copies. Keys 1–9 paste the newest snippets."
        case .todo: "A short list for today."
        case .timer: "Pomodoro focus sessions, countdowns and a stopwatch."
        case .calendar: "The month, with events for the day you select."
        case .stats: "Battery details."
        case .notes: "A scratchpad that saves as you type."
        case .calculator: "Type a sum and press Return."
        case .quickSearch: "Search the web from the notch."
        case .launcher: "Open apps from the notch."
        case .emoji: "Click an emoji to copy it."
        case .mirror: "A quick camera check before a call."
        }
    }

    static let defaultOrder: [TabID] = [.home, .nowPlaying, .shelf, .clipboard, .todo, .timer, .calendar]
}

enum HomeCardID: String, CaseIterable, Identifiable, Codable {
    case nowPlaying, calendar, controls, todo, battery, system, weather

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nowPlaying: "Now Playing"
        case .calendar: "Today"
        case .controls: "Quick Controls"
        case .todo: "To-Do"
        case .battery: "Battery"
        case .system: "System"
        case .weather: "Weather"
        }
    }

    var symbol: String {
        switch self {
        case .nowPlaying: "play.circle.fill"
        case .calendar: "calendar"
        case .controls: "switch.2"
        case .todo: "checklist"
        case .battery: "battery.100percent"
        case .system: "cpu"
        case .weather: "cloud.sun.fill"
        }
    }

    /// Relative width on the Home row.
    var weight: CGFloat {
        switch self {
        case .nowPlaying: 1.9
        case .calendar, .todo: 1.35
        case .controls, .battery, .system, .weather: 1
        }
    }
}

enum ShortcutID: String, CaseIterable, Identifiable, Codable {
    case toggleIsland, commandPalette, clipboard, dockClipboard, todo, shelf, pomodoro, caffeine, pin, playPause, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toggleIsland: "Open or Close the Island"
        case .commandPalette: "Command Palette"
        case .clipboard: "Clipboard History"
        case .dockClipboard: "Dock Clipboard"
        case .todo: "To-Do"
        case .shelf: "Shelf"
        case .pomodoro: "Start or Pause Pomodoro"
        case .caffeine: "Toggle Caffeine"
        case .pin: "Pin the Island"
        case .playPause: "Play or Pause Media"
        case .settings: "Settings"
        }
    }

    var defaultCombo: KeyCombo? {
        let ctrlOpt = UInt32(controlKey | optionKey)
        switch self {
        case .toggleIsland: return KeyCombo(keyCode: UInt32(kVK_Space), modifiers: ctrlOpt)
        case .commandPalette: return KeyCombo(keyCode: UInt32(kVK_ANSI_K), modifiers: ctrlOpt)
        case .clipboard: return KeyCombo(keyCode: UInt32(kVK_ANSI_C), modifiers: ctrlOpt | UInt32(shiftKey))
        case .dockClipboard: return KeyCombo(keyCode: UInt32(kVK_ANSI_C), modifiers: ctrlOpt)
        case .todo: return KeyCombo(keyCode: UInt32(kVK_ANSI_T), modifiers: ctrlOpt)
        case .shelf: return KeyCombo(keyCode: UInt32(kVK_ANSI_S), modifiers: ctrlOpt)
        case .pomodoro: return KeyCombo(keyCode: UInt32(kVK_ANSI_P), modifiers: ctrlOpt)
        case .caffeine: return KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: ctrlOpt)
        case .pin: return KeyCombo(keyCode: UInt32(kVK_ANSI_I), modifiers: ctrlOpt)
        case .playPause: return KeyCombo(keyCode: UInt32(kVK_ANSI_M), modifiers: ctrlOpt)
        case .settings: return KeyCombo(keyCode: UInt32(kVK_ANSI_Comma), modifiers: ctrlOpt)
        }
    }
}

/// A global shortcut in Carbon terms, which is what `RegisterEventHotKey` takes.
struct KeyCombo: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32

    var display: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + KeyCombo.keyName(keyCode)
    }

    var menuKeyEquivalent: String {
        let name = KeyCombo.keyName(keyCode)
        switch Int(keyCode) {
        case kVK_Space: return " "
        case kVK_Return: return "\r"
        default: return name.count == 1 ? name.lowercased() : ""
        }
    }

    var menuModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        // A global shortcut needs ⌘, ⌃ or ⌥ so plain typing never triggers it.
        guard carbon & UInt32(cmdKey | controlKey | optionKey) != 0 else { return nil }
        self.init(keyCode: UInt32(event.keyCode), modifiers: carbon)
    }

    static func keyName(_ code: UInt32) -> String {
        let names: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E",
            kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J",
            kVK_ANSI_K: "K", kVK_ANSI_L: "L", kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O",
            kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
            kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X", kVK_ANSI_Y: "Y",
            kVK_ANSI_Z: "Z", kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
            kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8",
            kVK_ANSI_9: "9", kVK_ANSI_Comma: ",", kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/",
            kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'", kVK_ANSI_LeftBracket: "[",
            kVK_ANSI_RightBracket: "]", kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_Grave: "`",
            kVK_ANSI_Backslash: "\\", kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥",
            kVK_Escape: "⎋", kVK_Delete: "⌫", kVK_LeftArrow: "←", kVK_RightArrow: "→",
            kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3",
            kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9",
            kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        return names[Int(code)] ?? "Key \(code)"
    }
}

enum PanelSize: String, CaseIterable, Identifiable, Codable {
    case compact, regular, large
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var width: CGFloat {
        switch self {
        case .compact: 620
        case .regular: 700
        case .large: 800
        }
    }

    var contentHeight: CGFloat {
        switch self {
        case .compact: 168
        case .regular: 188
        case .large: 220
        }
    }
}

enum ClipboardSound: String, CaseIterable, Identifiable, Codable {
    case none, pop, click, bubble, chime, glass, bell, note, water, cash
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "None"
        case .pop: "Pop"
        case .click: "Click"
        case .bubble: "Bubble"
        case .chime: "Chime"
        case .glass: "Glass"
        case .bell: "Bell"
        case .note: "Note"
        case .water: "Water Drop"
        case .cash: "Cash"
        }
    }
}

enum CursorStyle: String, CaseIterable, Identifiable, Codable {
    case system, arrow, dot, crosshair, beam
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "Mac Cursor"
        case .arrow: "Arrow"
        case .dot: "Dot"
        case .crosshair: "Crosshair"
        case .beam: "I-Beam"
        }
    }
}

enum TranslucencyProfile: String, CaseIterable, Identifiable, Codable {
    case graphite, carbon, satin, slate, ink, ocean, dusk
    var id: String { rawValue }
    var title: String {
        switch self {
        case .graphite: "Graphite"
        case .carbon: "Carbon"
        case .satin: "Satin"
        case .slate: "Slate"
        case .ink: "Ink"
        case .ocean: "Ocean"
        case .dusk: "Dusk"
        }
    }

    var summary: String {
        switch self {
        case .graphite: "Dense charcoal glass"
        case .carbon: "Near-black, like the camera housing"
        case .satin: "Soft warm dark"
        case .slate: "Cool gray glass"
        case .ink: "Blue-black"
        case .ocean: "Deep teal"
        case .dusk: "Dim violet"
        }
    }

    var fill: Color {
        switch self {
        case .graphite: Color(white: 0.14).opacity(0.94)
        case .carbon: Color.black.opacity(0.96)
        case .satin: Color(red: 0.13, green: 0.11, blue: 0.12).opacity(0.9)
        case .slate: Color(red: 0.16, green: 0.18, blue: 0.2).opacity(0.92)
        case .ink: Color(red: 0.04, green: 0.06, blue: 0.12).opacity(0.94)
        case .ocean: Color(red: 0.03, green: 0.12, blue: 0.14).opacity(0.92)
        case .dusk: Color(red: 0.12, green: 0.08, blue: 0.16).opacity(0.92)
        }
    }

    var material: NSVisualEffectView.Material {
        switch self {
        case .graphite: .sidebar
        case .carbon: .hudWindow
        case .satin: .menu
        case .slate: .popover
        case .ink: .underWindowBackground
        case .ocean: .headerView
        case .dusk: .sheet
        }
    }
}

enum IslandScreen: String, CaseIterable, Identifiable, Codable {
    case all, builtIn, main, external
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "All"
        case .builtIn: "Built-in"
        case .main: "Main"
        case .external: "External"
        }
    }

    func matches(_ screen: NSScreen) -> Bool {
        switch self {
        case .all: return true
        case .main: return screen == NSScreen.main
        case .builtIn: return screen.isBuiltIn
        case .external: return !screen.isBuiltIn
        }
    }
}

extension NSScreen {
    var isBuiltIn: Bool {
        let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
        return CGDisplayIsBuiltin(number) != 0
    }
}

enum ShelfLifetime: String, CaseIterable, Identifiable, Codable {
    case never, five, ten, thirty, hour
    var id: String { rawValue }
    var title: String {
        switch self {
        case .never: "Never"
        case .five: "5 Minutes"
        case .ten: "10 Minutes"
        case .thirty: "30 Minutes"
        case .hour: "1 Hour"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .never: nil
        case .five: 5 * 60
        case .ten: 10 * 60
        case .thirty: 30 * 60
        case .hour: 60 * 60
        }
    }
}

enum CaffeineDuration: Int, CaseIterable, Identifiable, Codable {
    case indefinitely = 0, fifteenMinutes = 15, oneHour = 60, twoHours = 120, fourHours = 240
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .indefinitely: "Until Turned Off"
        case .fifteenMinutes: "15 Minutes"
        case .oneHour: "1 Hour"
        case .twoHours: "2 Hours"
        case .fourHours: "4 Hours"
        }
    }
}

struct Preferences: Codable, Equatable {
    // General
    var launchAtLogin = false
    var showMenuBarIcon = false
    var menuBarClipboard = false
    var menuBarTodo = false
    var followPointerDisplay = false

    // Island
    var openOnHover = true
    var hoverDelay: Double = 0.15
    var closeOnMouseExit = true
    var closeDelay: Double = 0.9
    var idleTimeout: Double = 0
    /// Closes the island after the pointer has been away. Zero keeps the shorter collapse delay.
    var idleTimeoutAway: Double = 0
    var openOnCurrentActivity = false
    var defaultTab: TabID = .home
    var islandScreen: IslandScreen = .all
    var hapticFeedback = true
    var hapticOnClick = true
    var panelSize: PanelSize = .regular
    var rememberLastTab = true
    var tabOrder: [TabID] = TabID.defaultOrder
    /// 1 keeps the closed pill on the camera housing; above 1 grows it.
    var closedPillScale: Double = 1
    /// Extra height on the live-activity pill so meters and percents aren’t clipped.
    var activityHeightExtra: Double = 4
    /// Extra width on each live-activity ear.
    var activityWidthExtra: Double = 12
    var glassSurface = false
    var translucency: TranslucencyProfile = .carbon
    var hideIslandFromScreenshots = false
    /// Spacing between expanded-island section icons, in points.
    var tabIconGap: Double = 2

    // Live activities
    var mediaActivity = true
    var alwaysShowNowPlaying = false
    var timerActivity = true
    var downloadActivity = true
    var caffeineActivity = true
    var chargingAlerts = true
    var lowBatteryAlert = true
    var volumeActivity = true
    var brightnessActivity = true
    /// Set once so earlier installs, which left the volume HUD off, pick up keyboard HUDs.
    var hudControlsEnabled = true
    var trackChangePeek = true
    var eventAlerts = true
    var eventAlertMinutes = 5

    // Home
    var homeCards: [HomeCardID] = [.nowPlaying, .calendar, .controls]

    // Now playing
    var artworkTint = true
    var keepPausedMediaSeconds: Double = 20
    /// Websites that may open the Now Playing pill. Every other website stays off it.
    var mediaAllowlist: [String] = []

    // Calendar
    var showAllDayEvents = true
    var showRemindersInTodo = false
    var dockTodo = false
    var dockClipboard = false
    var dockAudio = true
    /// Hides every dock chip without clearing which chips, positions, or glass settings were chosen.
    var dockShortcutsEnabled = true
    /// How much of the desktop shows through a dock chip. 0 is solid glass, 1 is clear.
    var dockIconTransparency: Double = 0.35
    /// Strength of the light sheen across the chip.
    var dockIconReflection: Double = 0.45
    /// Kept so an older single horizontal offset can be split into the left and right sliders.
    var dockOffsetX: Double = 0
    /// Positive moves the Bluetooth chip to the right.
    var dockOffsetLeft: Double = 0
    /// Positive moves the To-Do and Clipboard chips to the right.
    var dockOffsetRight: Double = 0
    /// Points to drop the chips below the Dock baseline.
    var dockOffsetY: Double = 0
    /// 1 is the default chip size; lower values shrink the dock shortcuts.
    var dockIconScale: Double = 1

    // Shelf
    var openShelfOnFileDrag = true
    var removeAfterAirDrop = false
    var screenshotsToShelf = false
    var downloadsToShelf = false
    /// How long a shelf copy stays before Mochy removes it. Never leaves files until you clear them.
    var shelfLifetime: ShelfLifetime = .never

    // Clipboard
    var clipboardHistory = true
    var clipboardLimit = 40
    var clipboardPersist = true
    var stripLinkTrackers = false
    var clipboardSound: ClipboardSound = .pop

    // To-Do
    var todoSoundOnAdd = true
    var todoSoundOnRemove = true
    var todoRecognizeURLs = true
    var todoTrimURLPrefix = true
    var todoStripTrackers = false
    var todoNewestOnTop = true

    var cursorStyle: CursorStyle = .system

    // Pomodoro
    var focusMinutes: Double = 25
    var shortBreakMinutes: Double = 5
    var longBreakMinutes: Double = 15
    var roundsBeforeLongBreak = 4
    var autoStartNextPhase = true
    var timerSound = true

    // Caffeine
    var caffeineKeepsDisplayOn = true
    var caffeineDefault: CaffeineDuration = .indefinitely

    // Shortcuts
    var shortcuts: [ShortcutID: KeyCombo] = Dictionary(
        uniqueKeysWithValues: ShortcutID.allCases.compactMap { id in id.defaultCombo.map { (id, $0) } }
    )

    // Developer
    var apiEnabled = false
    var apiPort = 9999
    var apiToken = Preferences.newToken()

    static let storageKey = "mochy.preferences.v3"
    /// Set by decoding when an older install still had the volume HUD turned off.
    static var needsHUDSave = false

    static func newToken() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24)).lowercased()
    }

    static func load() -> Preferences {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(Preferences.self, from: data)
        {
            return decoded
        }
        if let url = Bundle.main.url(forResource: "SeedPreferences", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(Preferences.self, from: data)
        {
            decoded.save()
            return decoded
        }
        return Preferences()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

extension Preferences {
    /// Decodes field by field so a preference added in a later version keeps its default
    /// instead of discarding everything the person already chose.
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func take<T: Decodable>(_ key: CodingKeys, _ into: inout T) {
            if let value = try? c.decode(T.self, forKey: key) { into = value }
        }
        take(.launchAtLogin, &launchAtLogin)
        take(.showMenuBarIcon, &showMenuBarIcon)
        take(.menuBarClipboard, &menuBarClipboard)
        take(.menuBarTodo, &menuBarTodo)
        take(.followPointerDisplay, &followPointerDisplay)
        take(.openOnHover, &openOnHover)
        take(.hoverDelay, &hoverDelay)
        take(.closeOnMouseExit, &closeOnMouseExit)
        take(.closeDelay, &closeDelay)
        take(.idleTimeout, &idleTimeout)
        take(.idleTimeoutAway, &idleTimeoutAway)
        take(.openOnCurrentActivity, &openOnCurrentActivity)
        take(.defaultTab, &defaultTab)
        take(.islandScreen, &islandScreen)
        take(.hapticFeedback, &hapticFeedback)
        take(.hapticOnClick, &hapticOnClick)
        take(.panelSize, &panelSize)
        take(.rememberLastTab, &rememberLastTab)
        take(.tabOrder, &tabOrder)
        take(.closedPillScale, &closedPillScale)
        take(.activityHeightExtra, &activityHeightExtra)
        take(.activityWidthExtra, &activityWidthExtra)
        take(.glassSurface, &glassSurface)
        take(.translucency, &translucency)
        take(.hideIslandFromScreenshots, &hideIslandFromScreenshots)
        take(.tabIconGap, &tabIconGap)
        take(.mediaActivity, &mediaActivity)
        take(.alwaysShowNowPlaying, &alwaysShowNowPlaying)
        take(.timerActivity, &timerActivity)
        take(.downloadActivity, &downloadActivity)
        take(.caffeineActivity, &caffeineActivity)
        take(.chargingAlerts, &chargingAlerts)
        take(.lowBatteryAlert, &lowBatteryAlert)
        take(.volumeActivity, &volumeActivity)
        take(.brightnessActivity, &brightnessActivity)
        if c.contains(.hudControlsEnabled) {
            take(.hudControlsEnabled, &hudControlsEnabled)
        } else {
            hudControlsEnabled = false
        }
        take(.trackChangePeek, &trackChangePeek)
        take(.eventAlerts, &eventAlerts)
        take(.eventAlertMinutes, &eventAlertMinutes)
        take(.homeCards, &homeCards)
        take(.artworkTint, &artworkTint)
        take(.keepPausedMediaSeconds, &keepPausedMediaSeconds)
        take(.mediaAllowlist, &mediaAllowlist)
        mediaAllowlist = mediaAllowlist.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        take(.showAllDayEvents, &showAllDayEvents)
        take(.showRemindersInTodo, &showRemindersInTodo)
        take(.dockTodo, &dockTodo)
        take(.dockClipboard, &dockClipboard)
        take(.dockAudio, &dockAudio)
        take(.dockShortcutsEnabled, &dockShortcutsEnabled)
        take(.dockIconTransparency, &dockIconTransparency)
        take(.dockIconReflection, &dockIconReflection)
        dockIconTransparency = min(max(dockIconTransparency, 0), 1)
        dockIconReflection = min(max(dockIconReflection, 0), 1)
        take(.dockOffsetX, &dockOffsetX)
        if c.contains(.dockOffsetLeft) {
            take(.dockOffsetLeft, &dockOffsetLeft)
            take(.dockOffsetRight, &dockOffsetRight)
        } else {
            dockOffsetLeft = -dockOffsetX
            dockOffsetRight = dockOffsetX
        }
        dockOffsetLeft = min(max(dockOffsetLeft, -350), 350)
        dockOffsetRight = min(max(dockOffsetRight, -350), 350)
        take(.dockOffsetY, &dockOffsetY)
        if dockOffsetY < 0 { dockOffsetY = 0 }
        if dockOffsetY > 480 { dockOffsetY = 480 }
        take(.dockIconScale, &dockIconScale)
        dockIconScale = min(max(dockIconScale, 0.5), 1)
        take(.openShelfOnFileDrag, &openShelfOnFileDrag)
        take(.removeAfterAirDrop, &removeAfterAirDrop)
        take(.screenshotsToShelf, &screenshotsToShelf)
        take(.downloadsToShelf, &downloadsToShelf)
        take(.shelfLifetime, &shelfLifetime)
        take(.clipboardHistory, &clipboardHistory)
        take(.clipboardLimit, &clipboardLimit)
        take(.clipboardPersist, &clipboardPersist)
        take(.stripLinkTrackers, &stripLinkTrackers)
        take(.clipboardSound, &clipboardSound)
        take(.todoSoundOnAdd, &todoSoundOnAdd)
        take(.todoSoundOnRemove, &todoSoundOnRemove)
        take(.todoRecognizeURLs, &todoRecognizeURLs)
        take(.todoTrimURLPrefix, &todoTrimURLPrefix)
        take(.todoStripTrackers, &todoStripTrackers)
        take(.todoNewestOnTop, &todoNewestOnTop)
        take(.cursorStyle, &cursorStyle)
        take(.focusMinutes, &focusMinutes)
        take(.shortBreakMinutes, &shortBreakMinutes)
        take(.longBreakMinutes, &longBreakMinutes)
        take(.roundsBeforeLongBreak, &roundsBeforeLongBreak)
        take(.autoStartNextPhase, &autoStartNextPhase)
        take(.timerSound, &timerSound)
        take(.caffeineKeepsDisplayOn, &caffeineKeepsDisplayOn)
        take(.caffeineDefault, &caffeineDefault)
        if let saved = try? c.decode(StoredShortcuts.self, forKey: .shortcuts) {
            shortcuts = saved.values
        }
        if shortcuts[.dockClipboard] == nil {
            let ctrlOpt = UInt32(controlKey | optionKey)
            let dockCopy = KeyCombo(keyCode: UInt32(kVK_ANSI_C), modifiers: ctrlOpt)
            shortcuts[.dockClipboard] = dockCopy
            if shortcuts[.clipboard] == dockCopy {
                shortcuts[.clipboard] = KeyCombo(keyCode: UInt32(kVK_ANSI_C), modifiers: ctrlOpt | UInt32(shiftKey))
            }
        }
        take(.apiEnabled, &apiEnabled)
        take(.apiPort, &apiPort)
        take(.apiToken, &apiToken)
        if !hudControlsEnabled {
            volumeActivity = true
            brightnessActivity = true
            hudControlsEnabled = true
            Preferences.needsHUDSave = true
        }
        tabOrder = tabOrder.filter { $0 != .stats }
        if tabOrder.isEmpty { tabOrder = TabID.defaultOrder }
        if defaultTab == .stats { defaultTab = .home }
        homeCards = homeCards.filter { $0 != .system }
        if homeCards.isEmpty { homeCards = [.nowPlaying, .calendar, .controls] }
    }
}

/// Reads saved shortcuts and drops ones this version no longer has, such as the removed window moves.
private struct StoredShortcuts: Decodable {
    let values: [ShortcutID: KeyCombo]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var values: [ShortcutID: KeyCombo] = [:]
        while !container.isAtEnd {
            let key = try container.decode(String.self)
            let combo = try container.decode(KeyCombo.self)
            if let id = ShortcutID(rawValue: key) { values[id] = combo }
        }
        self.values = values
    }
}
