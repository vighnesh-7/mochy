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
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = AppModel()
    private var island: IslandController?
    private var api: LocalAPI?
    private var settingsWindow: NSWindow?
    private var accessories: AccessoryChrome?
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_: Notification) {
        installMenu()
        NSApp.setActivationPolicy(.accessory)
        if let url = Bundle.main.url(forResource: "Mochy", withExtension: "icns"), let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
        model.openSettings = { [weak self] in self?.showSettings() }

        island = IslandController(model: model)
        model.start()

        let api = LocalAPI(model: model)
        api.sync()
        self.api = api
        let accessories = AccessoryChrome(model: model)
        model.openDockClipboard = { [weak accessories] in accessories?.presentClipboard() }
        self.accessories = accessories

        model.$prefs
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.api?.sync() }
            .store(in: &bag)
    }

    func applicationWillTerminate(_: Notification) {
        api?.stop()
        model.stop()
        island?.teardown()
        accessories?.teardown()
    }

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

    // MARK: Menu

    private func installMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Mochy", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(menuSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Mochy", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Mochy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        let close = NSMenuItem(title: "Close", action: #selector(menuClose), keyEquivalent: "w")
        close.target = self
        fileMenu.addItem(close)
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        NSApp.mainMenu = main
    }

    @objc private func menuSettings() {
        showSettings()
    }

    @objc private func menuClose() {
        if let settingsWindow, settingsWindow.isVisible {
            settingsWindow.performClose(nil)
            return
        }
        model.collapse()
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
        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}
