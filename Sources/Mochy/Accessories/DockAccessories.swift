import AppKit
import Combine
import CoreGraphics
import SwiftUI

/// Compact to-do and clipboard cards used by the menu bar and the dock-adjacent chips.
struct CompactTodoCard: View {
    @ObservedObject var todo: TodoStore
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("To-Do").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(todo.openCount)").font(.system(size: 11, weight: .medium).monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill").foregroundStyle(.orange)
                TextField("New item", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit {
                        todo.add(draft)
                        draft = ""
                    }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            if todo.items.isEmpty {
                Text("Nothing yet").font(.system(size: 12)).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 36)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(todo.ordered) { item in
                            HStack(spacing: 8) {
                                Button { todo.toggle(item) } label: {
                                    Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(item.done ? Color.green : .secondary)
                                }
                                .buttonStyle(.plain)
                                TodoTitle(title: item.title, done: item.done, size: 12.5)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 6)
                            .frame(minHeight: 26)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 280)
        .frame(maxHeight: 220)
        .onAppear { focused = true }
    }
}

struct CompactClipboardCard: View {
    @ObservedObject var clipboard: ClipboardService
    var onPick: ((ClipItem) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Clipboard").font(.system(size: 13, weight: .semibold))
            if clipboard.filtered.isEmpty {
                Text("Nothing copied yet").font(.system(size: 12)).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 36)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(Array(clipboard.filtered.prefix(9).enumerated()), id: \.element.id) { index, item in
                            HStack(spacing: 6) {
                                Text(item.text)
                                    .font(.system(size: 12))
                                    .lineLimit(2)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if let url = item.openURL {
                                    Button {
                                        NSWorkspace.shared.open(url)
                                    } label: {
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 11, weight: .bold))
                                            .frame(width: 22, height: 22)
                                            .background(Capsule().fill(.white.opacity(0.14)))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Open link")
                                    .accessibilityLabel("Open Link")
                                }
                                Text("\(index + 1)")
                                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let onPick {
                                    onPick(item)
                                } else {
                                    clipboard.copy(item)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction(named: "Copy") {
                                if let onPick {
                                    onPick(item)
                                } else {
                                    clipboard.copy(item)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 280)
        .frame(maxHeight: 220)
    }
}

struct GlassChip: View {
    let symbol: String
    let label: String
    var badge: String?
    var tint: Color = .white
    var glow = false
    var size: CGFloat = 56
    var transparency: Double = 0.35
    var reflection: Double = 0.45
    let action: () -> Void

    var body: some View {
        let icon = max(24, size * 40 / 56)
        let radius = max(8, size * 13 / 56)
        let pad = max(4, size * 8 / 56)
        return Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: symbol)
                    .font(.system(size: max(11, size * 16 / 56), weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: icon, height: icon)
                    .background {
                        VisualEffect(material: .hudWindow, blending: .behindWindow)
                            .opacity(1 - transparency * 0.85)
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.white.opacity(0.14 * (1 - transparency)))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.55 * reflection),
                                        .white.opacity(0.05 * reflection),
                                        .clear,
                                        .white.opacity(0.18 * reflection)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .allowsHitTesting(false)
                    }
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(.white.opacity(0.22 * (1 - transparency * 0.4)), lineWidth: 0.8))
                    .padding(pad)
                if let badge {
                    Text(badge)
                        .font(.system(size: max(7, size * 9 / 56), weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                        .foregroundStyle(.white)
                        .padding(3)
                } else if glow {
                    ConnectGlow()
                        .padding(6)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct ConnectGlow: View {
    @State private var lit = false

    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 11, height: 11)
            .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1))
            .shadow(color: .green.opacity(lit ? 0.95 : 0.35), radius: lit ? 8 : 2)
            .scaleEffect(lit ? 1.15 : 0.8)
            .onAppear { withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { lit = true } }
            .accessibilityLabel("Device connected")
    }
}

struct AudioConnectBanner: View {
    let name: String
    let airPods: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: airPods ? "airpodspro" : "headphones")
                .font(.system(size: 18, weight: .semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text("Connected").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                Text(name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 220, alignment: .leading)
        .background {
            VisualEffect(material: .hudWindow)
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.08))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.2), lineWidth: 0.8))
    }
}

/// Floating glass chips beside the Dock, plus compact popovers for To-Do and Clipboard.
@MainActor
final class AccessoryChrome {
    private let model: AppModel
    private let audio = AudioDeviceMonitor()
    private var rightPanel: NSPanel?
    private var leftPanel: NSPanel?
    private var popover: NSPanel?
    private var banner: NSPanel?
    private var outsideMonitor: Any?
    private var bag = Set<AnyCancellable>()
    private var bannerWork: DispatchWorkItem?
    private var todoItem: NSStatusItem?
    private var clipboardItem: NSStatusItem?
    private var menuTargets: [StatusClick] = []
    private var escapeMonitor: Any?
    private var armOutside: DispatchWorkItem?

    init(model: AppModel) {
        self.model = model
        if model.prefs.dockAudio { audio.start() }
        audio.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncDock() }
            .store(in: &bag)
        audio.$announce
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] name in self?.showAudioBanner(name) }
            .store(in: &bag)
        model.$prefs
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.model.prefs.dockAudio { self.audio.start() }
                self.syncMenuBar()
                self.syncDock()
            }
            .store(in: &bag)
        model.todo.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncDock() }
            .store(in: &bag)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncDock() }
            .store(in: &bag)
        NotificationCenter.default.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncDock() }
            .store(in: &bag)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncDock() }
            .store(in: &bag)
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover?.isVisible == true else { return event }
            if event.keyCode == 53 {
                self.dismissPopover()
                return nil
            }
            guard self.popoverKind == .clipboard else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.isDisjoint(with: [.command, .control, .option, .shift]) else { return event }
            guard let slot = Int(event.charactersIgnoringModifiers ?? ""), (1 ... 9).contains(slot) else { return event }
            let items = self.model.clipboard.filtered
            guard slot <= items.count else { return event }
            self.pickClipboard(items[slot - 1])
            return nil
        }
        syncMenuBar()
        syncDock()
    }

    func presentClipboard() {
        togglePopover(.clipboard)
    }

    func teardown() {
        audio.stop()
        dismissPopover()
        [rightPanel, leftPanel, banner].forEach { $0?.orderOut(nil) }
        if let todoItem { NSStatusBar.system.removeStatusItem(todoItem) }
        if let clipboardItem { NSStatusBar.system.removeStatusItem(clipboardItem) }
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
    }

    // MARK: Menu bar

    private func syncMenuBar() {
        menuTargets.removeAll()
        todoItem = barButton(todoItem, visible: model.prefs.menuBarTodo, symbol: "checklist", name: "To-Do") { [weak self] in
            self?.togglePopover(.todo, from: self?.todoItem)
        }
        clipboardItem = barButton(clipboardItem, visible: model.prefs.menuBarClipboard, symbol: "doc.on.clipboard", name: "Clipboard") { [weak self] in
            self?.togglePopover(.clipboard, from: self?.clipboardItem)
        }
    }

    private func barButton(_ existing: NSStatusItem?, visible: Bool, symbol: String, name: String, action: @escaping () -> Void) -> NSStatusItem? {
        guard visible else {
            if let existing { NSStatusBar.system.removeStatusItem(existing) }
            return nil
        }
        let item = existing ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let target = StatusClick(action)
        menuTargets.append(target)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: name)
            button.target = target
            button.action = #selector(StatusClick.fire)
        }
        item.isVisible = true
        return item
    }

    // MARK: Dock chips

    private func syncDock() {
        guard model.prefs.dockShortcutsEnabled else {
            rightPanel?.orderOut(nil)
            leftPanel?.orderOut(nil)
            dismissPopover()
            return
        }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let dock = DockGeometry.frame(on: screen)
        let scale = CGFloat(min(max(model.prefs.dockIconScale, 0.5), 1))
        let panelH: CGFloat = 60 * scale
        let chipW: CGFloat = 60 * scale
        let chipSize: CGFloat = 56 * scale
        let gap: CGFloat = 14
        let vis = screen.visibleFrame
        let shiftLeft = CGFloat(model.prefs.dockOffsetLeft)
        let shiftRight = CGFloat(model.prefs.dockOffsetRight)
        let lower = CGFloat(model.prefs.dockOffsetY)
        let alignedY: CGFloat
        let alignedLeftX: CGFloat
        let alignedRightX: (CGFloat) -> CGFloat
        if let dock, dock.width >= dock.height {
            alignedY = dock.midY - panelH / 2
            alignedLeftX = dock.minX - gap - chipW
            alignedRightX = { _ in dock.maxX + gap }
        } else if let dock {
            alignedY = dock.minY
            alignedLeftX = dock.midX - chipW / 2
            alignedRightX = { width in dock.midX - width / 2 }
        } else {
            let dockHeight = max(vis.minY - screen.frame.minY, 56)
            alignedY = screen.frame.minY + (dockHeight - panelH) / 2
            alignedLeftX = vis.minX + 14
            alignedRightX = { width in vis.maxX - width - 14 }
        }
        let y = max(screen.frame.minY + 2, alignedY - lower)
        func clampX(_ x: CGFloat, width: CGFloat) -> CGFloat {
            min(max(x, vis.minX + 4), vis.maxX - width - 4)
        }

        var right: [(symbol: String, label: String, badge: String?, action: () -> Void)] = []
        if model.prefs.dockTodo {
            right.append(("checklist", "To-Do", model.todo.openCount > 0 ? "\(model.todo.openCount)" : nil, { [weak self] in self?.togglePopover(.todo, anchor: nil) }))
        }
        if model.prefs.dockClipboard {
            right.append(("doc.on.clipboard.fill", "Clipboard", nil, { [weak self] in self?.togglePopover(.clipboard, anchor: nil) }))
        }

        if right.isEmpty {
            rightPanel?.orderOut(nil)
            rightPanel = nil
        } else {
            let width = CGFloat(right.count) * chipW
            let panel = reuse(&rightPanel, size: CGSize(width: width, height: panelH))
            let view = HStack(spacing: 4) {
                ForEach(Array(right.enumerated()), id: \.offset) { _, item in
                    GlassChip(
                        symbol: item.symbol,
                        label: item.label,
                        badge: item.badge,
                        size: chipSize,
                        transparency: self.model.prefs.dockIconTransparency,
                        reflection: self.model.prefs.dockIconReflection,
                        action: item.action
                    )
                }
            }
            .environment(\.colorScheme, .dark)
            host(view, in: panel, card: false)
            let x = clampX(clampX(alignedRightX(width), width: width) + shiftRight, width: width)
            panel.setFrame(NSRect(x: x, y: y, width: width, height: panelH), display: true)
            panel.orderFrontRegardless()
        }

        if model.prefs.dockAudio, let name = audio.connectedName {
            let panel = reuse(&leftPanel, size: CGSize(width: chipW, height: panelH))
            host(GlassChip(
                symbol: audio.symbol,
                label: name,
                glow: audio.showGlow,
                size: chipSize,
                transparency: model.prefs.dockIconTransparency,
                reflection: model.prefs.dockIconReflection,
                action: { [weak self] in self?.showAudioBanner(name) }
            ).environment(\.colorScheme, .dark), in: panel, card: false)
            let x = clampX(clampX(alignedLeftX, width: chipW) + shiftLeft, width: chipW)
            panel.setFrame(NSRect(x: x, y: y, width: chipW, height: panelH), display: true)
            panel.orderFrontRegardless()
        } else {
            leftPanel?.orderOut(nil)
            leftPanel = nil
        }
    }

    private func showAudioBanner(_ name: String) {
        guard model.prefs.dockAudio else { return }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let vis = screen.visibleFrame
        let panel = reuse(&banner, size: CGSize(width: 236, height: 56))
        host(AudioConnectBanner(name: name, airPods: audio.isAirPods).environment(\.colorScheme, .dark), in: panel)
        let y = (leftPanel?.frame.maxY ?? vis.minY) + 10
        panel.setFrameOrigin(NSPoint(x: vis.minX + 14, y: y))
        panel.orderFrontRegardless()
        bannerWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.banner?.orderOut(nil)
            self?.audio.announce = nil
        }
        bannerWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }

    // MARK: Popover

    private enum Kind { case todo, clipboard }
    private var popoverKind: Kind?

    private func togglePopover(_ kind: Kind, from item: NSStatusItem? = nil, anchor: NSPoint? = nil) {
        if popover?.isVisible == true {
            dismissPopover()
            return
        }
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier
        {
            model.previousFrontApp = front
        }
        let size = NSSize(width: 304, height: 236)
        let panel = reuse(&popover, size: size)
        popoverKind = kind
        (panel as? AccessoryPanel)?.acceptsKey = true
        panel.level = .popUpMenu
        switch kind {
        case .todo:
            host(CompactTodoCard(todo: model.todo).environmentObject(model).environment(\.colorScheme, .dark), in: panel)
        case .clipboard:
            host(CompactClipboardCard(clipboard: model.clipboard, onPick: { [weak self] item in
                self?.pickClipboard(item)
            }).environment(\.colorScheme, .dark), in: panel)
        }
        if let button = item?.button, let window = button.window {
            let rect = button.convert(button.bounds, to: nil)
            let screen = window.convertToScreen(rect)
            panel.setFrameOrigin(NSPoint(x: screen.midX - size.width + 28, y: screen.minY - size.height - 8))
        } else if let right = rightPanel {
            panel.setFrameOrigin(NSPoint(x: right.frame.maxX - size.width, y: right.frame.maxY + 8))
        } else {
            panel.center()
        }
        panel.orderFrontRegardless()
        panel.makeKey()
        if kind == .clipboard { NSApp.activate(ignoringOtherApps: true) }
        installOutside()
    }

    private func clickIsOnDockChrome(_ point: NSPoint) -> Bool {
        if let popover, popover.frame.contains(point) { return true }
        if let rightPanel, rightPanel.frame.contains(point) { return true }
        if let leftPanel, leftPanel.frame.contains(point) { return true }
        return false
    }

    private func pickClipboard(_ item: ClipItem) {
        dismissPopover()
        model.pastePlainText(item.text)
    }

    private func dismissPopover() {
        popoverKind = nil
        armOutside?.cancel()
        armOutside = nil
        (popover as? AccessoryPanel)?.acceptsKey = false
        popover?.makeFirstResponder(nil)
        popover?.orderOut(nil)
        releaseShortcutFocus()
        model.todo.commitCompleted()
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }
        outsideMonitor = nil
        if let front = model.previousFrontApp, front.bundleIdentifier != Bundle.main.bundleIdentifier {
            front.activate()
        }
    }

    /// The chip stays the key window after the card closes, so the blue focus ring remains and Space opens it again.
    private func releaseShortcutFocus() {
        for panel in [rightPanel, leftPanel] {
            guard let panel else { continue }
            (panel as? AccessoryPanel)?.acceptsKey = false
            panel.makeFirstResponder(nil)
            guard panel.isKeyWindow else { continue }
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
    }

    private func installOutside() {
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }
        outsideMonitor = nil
        armOutside?.cancel()
        // Wait until the opening click has finished. Installing during that click
        // was closing the card before it could appear, until the app was relaunched.
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.popover?.isVisible == true else { return }
            self.outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if self.clickIsOnDockChrome(NSEvent.mouseLocation) { return }
                    self.dismissPopover()
                }
            }
        }
        armOutside = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func reuse(_ slot: inout NSPanel?, size: CGSize) -> NSPanel {
        let panel = slot ?? AccessoryPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.sharingType = model.prefs.hideIslandFromScreenshots ? .none : .readWrite
        slot = panel
        panel.setContentSize(size)
        return panel
    }

    private func host<V: View>(_ view: V, in panel: NSPanel, card: Bool = true) {
        let wrapped: AnyView
        if card {
            wrapped = AnyView(view
                .background {
                    VisualEffect(material: .hudWindow)
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.black.opacity(0.25))
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)))
            panel.hasShadow = true
        } else {
            wrapped = AnyView(view)
            panel.hasShadow = false
        }
        if let existing = panel.contentView as? FirstMouseHostingView<AnyView> {
            existing.rootView = wrapped
        } else {
            panel.contentView = FirstMouseHostingView(rootView: wrapped)
        }
        panel.ignoresMouseEvents = false
    }
}

private final class AccessoryPanel: NSPanel {
    /// Only the open card takes the keyboard. A shortcut chip that stays key keeps a blue ring and Space reopens it.
    var acceptsKey = false
    override var canBecomeKey: Bool { acceptsKey }
    override var canBecomeMain: Bool { false }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }
}

enum DockGeometry {
    static func frame(on screen: NSScreen) -> NSRect? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        var best: NSRect?
        for window in list {
            guard (window[kCGWindowOwnerName as String] as? String) == "Dock" else { continue }
            guard let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let width = bounds["Width"] ?? 0
            let height = bounds["Height"] ?? 0
            if width < 40 || height < 32 { continue }
            let quartz = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: width, height: height)
            let rect = cocoa(quartz)
            if best == nil || rect.width * rect.height > best!.width * best!.height {
                best = rect
            }
        }
        return best
    }

    private static func cocoa(_ quartz: CGRect) -> NSRect {
        let primary = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main ?? NSScreen.screens[0]
        return NSRect(
            x: quartz.origin.x,
            y: primary.frame.maxY - quartz.origin.y - quartz.height,
            width: quartz.width,
            height: quartz.height
        )
    }
}

final class StatusClick: NSObject {
    private let handler: () -> Void
    init(_ handler: @escaping () -> Void) { self.handler = handler }
    @objc func fire() { handler() }
}
