import Carbon.HIToolbox
import Foundation
import SwiftUI

enum TabID: String, CaseIterable, Identifiable, Codable {
    case home, shelf, clipboard, todo, timer, calendar, stats
    case notes, calculator, quickSearch, launcher, emoji, mirror

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
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
        case .shelf: "Park files in the notch, drag them out, or AirDrop them."
        case .clipboard: "Recent copies. Click one to copy it again."
        case .todo: "A short list for today."
        case .timer: "Pomodoro focus sessions, countdowns and a stopwatch."
        case .calendar: "Today’s agenda with Join buttons for video calls."
        case .stats: "CPU, memory, network, storage and battery vitals."
        case .notes: "A scratchpad that saves as you type."
        case .calculator: "Type a sum and press Return."
        case .quickSearch: "Search the web from the notch."
        case .launcher: "Open apps from the notch."
        case .emoji: "Click an emoji to copy it."
        case .mirror: "A quick camera check before a call."
        }
    }

    static let defaultOrder: [TabID] = [.home, .shelf, .clipboard, .todo, .timer, .calendar, .stats]
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
    case toggleIsland, commandPalette, clipboard, todo, shelf, pomodoro, caffeine, pin, playPause, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toggleIsland: "Open or Close the Island"
        case .commandPalette: "Command Palette"
        case .clipboard: "Clipboard History"
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
        case .clipboard: return KeyCombo(keyCode: UInt32(kVK_ANSI_C), modifiers: ctrlOpt)
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
        case .compact: 580
        case .regular: 660
        case .large: 760
        }
    }

    var contentHeight: CGFloat {
        switch self {
        case .compact: 150
        case .regular: 176
        case .large: 210
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
    var showMenuBarIcon = true
    var followPointerDisplay = false

    // Island
    var openOnHover = true
    var hoverDelay: Double = 0.15
    var closeOnMouseExit = true
    var closeDelay: Double = 0.4
    var hapticFeedback = true
    var panelSize: PanelSize = .regular
    var rememberLastTab = true
    var tabOrder: [TabID] = TabID.defaultOrder

    // Live activities
    var mediaActivity = true
    var timerActivity = true
    var downloadActivity = true
    var caffeineActivity = true
    var chargingAlerts = true
    var lowBatteryAlert = true
    var volumeActivity = false
    var trackChangePeek = true
    var eventAlerts = true
    var eventAlertMinutes = 5

    // Home
    var homeCards: [HomeCardID] = [.nowPlaying, .calendar, .controls]

    // Now playing
    var artworkTint = true
    var keepPausedMediaSeconds: Double = 20

    // Calendar
    var showAllDayEvents = true
    var showRemindersInTodo = true

    // Shelf
    var openShelfOnFileDrag = true
    var removeAfterAirDrop = false
    var screenshotsToShelf = false
    var downloadsToShelf = false

    // Clipboard
    var clipboardHistory = true
    var clipboardLimit = 40
    var stripLinkTrackers = false

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

    static func newToken() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24)).lowercased()
    }

    static func load() -> Preferences {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(Preferences.self, from: data)
        else { return Preferences() }
        return decoded
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
        take(.followPointerDisplay, &followPointerDisplay)
        take(.openOnHover, &openOnHover)
        take(.hoverDelay, &hoverDelay)
        take(.closeOnMouseExit, &closeOnMouseExit)
        take(.closeDelay, &closeDelay)
        take(.hapticFeedback, &hapticFeedback)
        take(.panelSize, &panelSize)
        take(.rememberLastTab, &rememberLastTab)
        take(.tabOrder, &tabOrder)
        take(.mediaActivity, &mediaActivity)
        take(.timerActivity, &timerActivity)
        take(.downloadActivity, &downloadActivity)
        take(.caffeineActivity, &caffeineActivity)
        take(.chargingAlerts, &chargingAlerts)
        take(.lowBatteryAlert, &lowBatteryAlert)
        take(.volumeActivity, &volumeActivity)
        take(.trackChangePeek, &trackChangePeek)
        take(.eventAlerts, &eventAlerts)
        take(.eventAlertMinutes, &eventAlertMinutes)
        take(.homeCards, &homeCards)
        take(.artworkTint, &artworkTint)
        take(.keepPausedMediaSeconds, &keepPausedMediaSeconds)
        take(.showAllDayEvents, &showAllDayEvents)
        take(.showRemindersInTodo, &showRemindersInTodo)
        take(.openShelfOnFileDrag, &openShelfOnFileDrag)
        take(.removeAfterAirDrop, &removeAfterAirDrop)
        take(.screenshotsToShelf, &screenshotsToShelf)
        take(.downloadsToShelf, &downloadsToShelf)
        take(.clipboardHistory, &clipboardHistory)
        take(.clipboardLimit, &clipboardLimit)
        take(.stripLinkTrackers, &stripLinkTrackers)
        take(.focusMinutes, &focusMinutes)
        take(.shortBreakMinutes, &shortBreakMinutes)
        take(.longBreakMinutes, &longBreakMinutes)
        take(.roundsBeforeLongBreak, &roundsBeforeLongBreak)
        take(.autoStartNextPhase, &autoStartNextPhase)
        take(.timerSound, &timerSound)
        take(.caffeineKeepsDisplayOn, &caffeineKeepsDisplayOn)
        take(.caffeineDefault, &caffeineDefault)
        take(.shortcuts, &shortcuts)
        take(.apiEnabled, &apiEnabled)
        take(.apiPort, &apiPort)
        take(.apiToken, &apiToken)
    }
}
