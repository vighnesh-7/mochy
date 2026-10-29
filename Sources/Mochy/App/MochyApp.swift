import AppKit
import Combine
import SwiftUI

@main
struct MochyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(delegate.model)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var island: IslandWindowController?
    private var pet: PetWindowController?
    private var settings: NSWindow?
    private var api: LocalAPI?
    private var statusItem: NSStatusItem?
    private var keyMonitor: Any?
    private var localKeyMonitor: Any?
    private var widgets: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        island = IslandWindowController(model: model)
        island?.showWindow(nil)
        island?.window?.orderFrontRegardless()
        pet = PetWindowController(model: model)
        updatePet()
        api = LocalAPI(model: model)
        api?.start()
        setupStatusItem()
        registerHotKey()
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.syncWindows() }
        }.store(in: &cancellables)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
    }

    private var cancellables: Set<AnyCancellable> = []

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model.expand()
        return false
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: string) else { return }
        model.handleURL(url)
    }

    @objc private func wake() {
        if model.enabledOverlays.contains(.lockUnlock) {
            model.showIsland(title: "Unlocked", message: "Welcome back", symbol: "lock.open.fill", tint: "green", duration: 1.6)
        }
    }

    private func syncWindows() {
        updatePet()
        if model.settingsOpen { showSettings() }
        island?.reposition()
        if let screen = NSScreen.main {
            island?.updateNotchCover(screen: screen)
        }
        updateStatusItem()
        updateWidgets()
    }

    private func updatePet() {
        if model.petOpen {
            pet?.showWindow(nil)
            pet?.window?.orderFrontRegardless()
        } else {
            pet?.window?.orderOut(nil)
        }
    }

    private func showSettings() {
        if settings == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 840, height: 560),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Mochy Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView().environmentObject(model))
            window.center()
            settings = window
        }
        NSApp.setActivationPolicy(.regular)
        settings?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: settings, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.model.settingsOpen = false
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "M"
        item.menu = NSMenu()
        item.menu?.addItem(withTitle: "Open Notch", action: #selector(openNotch), keyEquivalent: "")
        item.menu?.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        item.menu?.addItem(withTitle: "Command Palette", action: #selector(openPalette), keyEquivalent: "k")
        item.menu?.addItem(.separator())
        item.menu?.addItem(withTitle: "Quit Mochy", action: #selector(quit), keyEquivalent: "q")
        item.menu?.items.forEach { $0.target = self }
        statusItem = item
        updateStatusItem()
    }

    private func updateStatusItem() {
        guard let item = statusItem else { return }
        item.isVisible = model.prefs.showMenuBarIcon
        let formatter = DateFormatter()
        formatter.dateFormat = model.prefs.clock24h ? "HH:mm" : "h:mm"
        switch model.prefs.menuBarReadout {
        case "battery":
            item.button?.title = model.prefs.batteryInMenuBar ? "\(model.battery.percent)%" : "M"
        case "meeting":
            item.button?.title = model.calendar.nextEvent?.title.prefix(16).description ?? "M"
        default:
            item.button?.title = model.prefs.nextMeetingInMenuBar ? (model.calendar.nextEvent?.title.prefix(16).description ?? formatter.string(from: Date())) : formatter.string(from: Date())
        }
        if model.prefs.batteryInMenuBar {
            item.button?.title = "\(item.button?.title ?? "M") · \(model.battery.percent)%"
        }
    }

    private func updateWidgets() {
        guard model.prefs.desktopWidgets else {
            widgets?.orderOut(nil)
            return
        }
        if widgets == nil {
            let window = NSPanel(contentRect: NSRect(x: 24, y: 24, width: 280, height: 160), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window.ignoresMouseEvents = false
            window.contentView = NSHostingView(rootView: DesktopWidgetBoard().environmentObject(model))
            widgets = window
        }
        widgets?.orderFrontRegardless()
    }

    @objc private func openNotch() { model.expand() }
    @objc private func openSettings() { model.settingsOpen = true; showSettings() }
    @objc private func openPalette() { model.paletteOpen = true; model.expand() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func registerHotKey() {
        let handle: (NSEvent) -> Bool = { [weak self] event in
            guard let self else { return false }
            for action in ShortcutCatalog.all where AppModel.matches(self.model.prefs[keyPath: action.keyPath], event: event) {
                DispatchQueue.main.async { self.model.performShortcut(action) }
                return true
            }
            return false
        }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            _ = handle(event)
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event) ? nil : event
        }
    }
}

struct DesktopWidgetBoard: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.prefs.clockWidget {
                Text(timeString).font(.system(size: 28, weight: .semibold, design: .rounded))
            }
            if model.prefs.weatherWidget {
                Text("\(model.weather.temperature)  \(model.weather.condition)").font(.headline)
            }
            if model.prefs.worldClockWidget {
                Text(utcString).font(.caption).foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(width: 260, height: 140, alignment: .topLeading)
        .background(glass(width: 260, height: 140, corner: 18, opacity: model.prefs.widgetGlass ? model.prefs.glassOpacity : 0.9, look: model.prefs.glassLook))
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = model.prefs.clock24h ? "HH:mm" : "h:mm a"
        return f.string(from: Date())
    }

    private var utcString: String {
        let f = DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "'UTC' HH:mm"
        return f.string(from: Date())
    }
}
