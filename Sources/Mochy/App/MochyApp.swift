import AppKit
import Combine
import SwiftUI

@main
enum MochyMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    let model = AppModel()
    private var island: IslandController?
    private var api: LocalAPI?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model.openSettings = { [weak self] in self?.showSettings() }
        model.onShortcutsChanged = { [weak self] in self?.statusItem?.menu.map { self?.rebuild($0) } }

        island = IslandController(model: model)
        model.start()

        let api = LocalAPI(model: model)
        api.sync()
        self.api = api

        setupStatusItem()
        model.$prefs
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.api?.sync()
                self?.statusItem?.isVisible = self?.model.prefs.showMenuBarIcon ?? true
            }
            .store(in: &bag)
    }

    func applicationWillTerminate(_: Notification) {
        api?.stop()
        model.stop()
        island?.teardown()
    }

    /// Opening Mochy again from Finder or Spotlight shows Settings, which matters when the menu bar icon is hidden.
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        showSettings()
        return false
    }

    func application(_: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme?.lowercased() == "mochy" {
            handle(url)
        }
    }

    /// mochy://open, mochy://close, mochy://settings, mochy://palette, mochy://tab/<name>, mochy://pomodoro, mochy://caffeine
    private func handle(_ url: URL) {
        let host = url.host?.lowercased() ?? ""
        switch host {
        case "open", "expand", "show": model.expand()
        case "close", "collapse": model.collapse()
        case "settings": showSettings()
        case "palette": model.openPalette()
        case "pomodoro": model.runShortcut(.pomodoro)
        case "caffeine": model.runShortcut(.caffeine)
        case "tab":
            if let name = url.pathComponents.dropFirst().first, let tab = TabID(rawValue: name) { model.expand(tab: tab) }
        default:
            if let tab = TabID(rawValue: host) { model.expand(tab: tab) }
        }
    }

    // MARK: Settings window

    private func showSettings() {
        model.collapse()
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 820, height: 580),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Mochy Settings"
            window.toolbar = NSToolbar(identifier: "settings")
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: SettingsView().environmentObject(model))
            window.setContentSize(NSSize(width: 820, height: 580))
            window.center()
            window.setFrameAutosaveName("MochySettings")
            window.delegate = self
            settingsWindow = window
        }
        // Accessory apps can't own a focused standard window, so Mochy shows in the Dock while Settings is open.
        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: Status item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "capsule.portrait.tophalf.filled", accessibilityDescription: "Mochy")
                ?? NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Mochy")
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        item.isVisible = model.prefs.showMenuBarIcon
        statusItem = item
        rebuild(menu)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu)
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()
        if model.nowPlaying.hasMedia {
            let playing = NSMenuItem(title: "\(model.nowPlaying.title) — \(model.nowPlaying.artist.isEmpty ? model.nowPlaying.appName : model.nowPlaying.artist)", action: nil, keyEquivalent: "")
            playing.isEnabled = false
            menu.addItem(playing)
            menu.addItem(command(model.nowPlaying.isPlaying ? "Pause" : "Play", shortcut: .playPause) { [weak self] in self?.model.nowPlaying.playPause() })
            menu.addItem(command("Next Track") { [weak self] in self?.model.nowPlaying.next() })
            menu.addItem(.separator())
        }
        menu.addItem(command(model.isExpanded ? "Close the Island" : "Open the Island", shortcut: .toggleIsland) { [weak self] in self?.model.toggleIsland() })
        menu.addItem(command("Command Palette", shortcut: .commandPalette) { [weak self] in self?.model.openPalette() })
        menu.addItem(.separator())
        menu.addItem(command("Clipboard History", shortcut: .clipboard) { [weak self] in self?.model.expand(tab: .clipboard, keyboard: true) })
        menu.addItem(command("To-Do", shortcut: .todo) { [weak self] in self?.model.expand(tab: .todo, keyboard: true) })
        menu.addItem(command("Shelf", shortcut: .shelf) { [weak self] in self?.model.expand(tab: .shelf) })
        menu.addItem(.separator())
        menu.addItem(command(model.timer.isRunning ? "Pause Timer" : "Start Pomodoro", shortcut: .pomodoro) { [weak self] in self?.model.togglePomodoro() })
        let caffeine = command(model.caffeine.isActive ? "Turn Off Caffeine" : "Turn On Caffeine", shortcut: .caffeine) { [weak self] in self?.model.toggleCaffeine() }
        caffeine.state = model.caffeine.isActive ? .on : .off
        menu.addItem(caffeine)
        let pin = command("Pin the Island", shortcut: .pin) { [weak self] in self?.model.runShortcut(.pin) }
        pin.state = model.pinned ? .on : .off
        menu.addItem(pin)
        menu.addItem(.separator())
        menu.addItem(command("Settings…", shortcut: .settings) { [weak self] in self?.showSettings() })
        menu.addItem(command("Quit Mochy") { NSApp.terminate(nil) })
    }

    private func command(_ title: String, shortcut: ShortcutID? = nil, action: @escaping () -> Void) -> NSMenuItem {
        let item = ClosureMenuItem(title: title, action: action)
        if let shortcut, let combo = model.prefs.shortcuts[shortcut], !combo.menuKeyEquivalent.isEmpty {
            item.keyEquivalent = combo.menuKeyEquivalent
            item.keyEquivalentModifierMask = combo.menuModifiers
        }
        return item
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, action handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) { fatalError("unused") }

    @objc private func run() { handler() }
}
