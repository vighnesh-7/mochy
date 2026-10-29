import SwiftUI

enum TabID: String, CaseIterable, Identifiable, Codable {
    case home, nowPlaying, calendar, reminders, notes, focus, translate
    case activity, aiUsage, askAI, launcher, packages, files, clipboard
    case shortcuts, calculator, quickSearch, notifications, todo, cuely
    case emoji, timer, mirror, stocks, homeKit, terminal, soundMixer, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .nowPlaying: "Now Playing"
        case .calendar: "Calendar"
        case .reminders: "Reminders"
        case .notes: "Notes"
        case .focus: "Focus"
        case .translate: "Translate"
        case .activity: "Activity"
        case .aiUsage: "AI Usage"
        case .askAI: "Ask AI"
        case .launcher: "Launcher"
        case .packages: "Packages"
        case .files: "Files"
        case .clipboard: "Clipboard"
        case .shortcuts: "Shortcuts"
        case .calculator: "Calculator"
        case .quickSearch: "Quick Search"
        case .notifications: "Notifications"
        case .todo: "Tasks"
        case .cuely: "Cuely"
        case .emoji: "Emoji"
        case .timer: "Timer"
        case .mirror: "Mirror"
        case .stocks: "Stocks"
        case .homeKit: "Home"
        case .terminal: "Terminal"
        case .soundMixer: "Sound Mixer"
        case .settings: "Quick Settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .nowPlaying: "music.note"
        case .calendar: "calendar"
        case .reminders: "checklist"
        case .notes: "note.text"
        case .focus: "moon.fill"
        case .translate: "globe"
        case .activity: "circle.circle"
        case .aiUsage: "chart.bar.fill"
        case .askAI: "sparkles"
        case .launcher: "square.grid.3x3.fill"
        case .packages: "shippingbox.fill"
        case .files: "folder.fill"
        case .clipboard: "doc.on.clipboard"
        case .shortcuts: "square.stack.3d.up.fill"
        case .calculator: "plus.forwardslash.minus"
        case .quickSearch: "magnifyingglass"
        case .notifications: "bell.fill"
        case .todo: "checkmark.circle"
        case .cuely: "text.alignleft"
        case .emoji: "face.smiling"
        case .timer: "timer"
        case .mirror: "web.camera.fill"
        case .stocks: "chart.line.uptrend.xyaxis"
        case .homeKit: "homekit"
        case .terminal: "terminal.fill"
        case .soundMixer: "slider.horizontal.3"
        case .settings: "switch.2"
        }
    }

    var blurb: String {
        switch self {
        case .home: "Arrange the notch’s Home tab — cards for music, weather, battery, next event and Mochi."
        case .nowPlaying: "Scrub bar, lyrics, volume and audio output, plus weather and your next events."
        case .calendar: "Agenda and next event, with a Join button for video calls."
        case .reminders: "Add and check off Apple Reminders right from the notch."
        case .notes: "A scratchpad in the notch — jot a thought without opening an app."
        case .focus: "Close your Move, Type and Focus rings, and flip Focus modes."
        case .translate: "Translate a phrase in the notch — ⌘⏎ runs it, ⌘⇧S swaps the languages."
        case .activity: "A three-ring glance beside the collapsed notch."
        case .aiUsage: "Usage from Claude, Codex, Cursor, Antigravity and Copilot, read on this Mac."
        case .askAI: "Chat with Claude right in the notch using your own API key."
        case .launcher: "Open apps and files from a launcher wheel in the notch."
        case .packages: "Apps with updates waiting — App Store, Homebrew and direct downloads."
        case .files: "Downloads show live progress in the notch and land on the Shelf."
        case .clipboard: "Clipboard history; items copy but never paste themselves."
        case .shortcuts: "Click a shortcut to run it from the notch."
        case .calculator: "Type a sum — percents, functions, and a history you can copy."
        case .quickSearch: "Type a query, hit return, it opens in your browser."
        case .notifications: "App banners in the notch, with reply where supported."
        case .todo: "Tasks due today, filed next to Reminders."
        case .cuely: "A teleprompter in the notch — scroll a script while you present."
        case .emoji: "Pick an emoji without leaving the notch."
        case .timer: "Timers, a stopwatch and Pomodoro from the notch."
        case .mirror: "A quick camera glance without opening FaceTime."
        case .stocks: "Watchlist quotes and price alerts."
        case .homeKit: "Control HomeKit lights and scenes without leaving the notch."
        case .terminal: "A full command runner for your shell in the notch."
        case .soundMixer: "Adjust volume for each app plus an equalizer."
        case .settings: "Quick switches for Caffeine, Low Power Mode, appearance and more."
        }
    }

    static let defaultEnabled: Set<TabID> = [
        .home, .nowPlaying, .timer, .clipboard, .files, .calendar, .notes, .reminders,
    ]
}

enum OverlayID: String, CaseIterable, Identifiable, Codable {
    case charging, lowBattery, airPods, capsLock, volume, brightness
    case nowPlayingChange, screenshot, download, timerDone, call
    case notification, caffeine, spaceName, cameraInUse, agentPrompt
    case songChange, lockUnlock, connectivity, deviceBattery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .charging: "Charging Island"
        case .lowBattery: "Battery Alerts"
        case .airPods: "AirPods"
        case .capsLock: "Caps Lock HUD"
        case .volume: "Volume HUD"
        case .brightness: "Brightness Overlay"
        case .nowPlayingChange: "Now Playing Island"
        case .screenshot: "Screenshots"
        case .download: "Downloads"
        case .timerDone: "Timer Alerts"
        case .call: "Call Islands"
        case .notification: "App banners"
        case .caffeine: "Caffeine"
        case .spaceName: "Space name"
        case .cameraInUse: "Camera island"
        case .agentPrompt: "Agent Permission Islands"
        case .songChange: "Song change pill"
        case .lockUnlock: "Unlock pill"
        case .connectivity: "Connectivity Islands"
        case .deviceBattery: "Accessory batteries"
        }
    }
}

struct HomeCard: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var symbol: String
    var enabled: Bool
}

enum IslandState: Equatable {
    case collapsed
    case expanded
    case transient
}

struct TransientIsland: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var message: String
    var symbol: String
    var tintName: String
    var duration: TimeInterval

    var tint: Color {
        switch tintName {
        case "green": .green
        case "red": .red
        case "orange": .orange
        case "blue": .blue
        case "yellow": .yellow
        case "pink": .pink
        default: Color(red: 0.45, green: 0.82, blue: 0.72)
        }
    }
}
