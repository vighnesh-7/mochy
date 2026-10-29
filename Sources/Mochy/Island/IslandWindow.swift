import AppKit
import Combine
import SwiftUI

final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }
}

/// Owns the island window: placement over the notch, click-through outside the island,
/// hover open and close, file-drag detection, and keyboard focus.
@MainActor
final class IslandController {
    /// Large enough for the biggest panel plus its shadow; everything outside the island passes clicks through.
    private static let canvas = CGSize(width: 900, height: 360)

    private let model: AppModel
    private let panel: IslandPanel
    private var monitors: [Any] = []
    private var bag = Set<AnyCancellable>()
    private var openWork: DispatchWorkItem?
    private var closeWork: DispatchWorkItem?
    /// Hover-close only applies once the pointer has been inside the open island,
    /// so an island opened from the keyboard doesn't close under a pointer that never arrived.
    private var pointerVisited = false
    private var dragChangeCount = NSPasteboard(name: .drag).changeCount
    private var screen: NSScreen?

    init(model: AppModel) {
        self.model = model
        panel = IslandPanel(
            contentRect: NSRect(origin: .zero, size: Self.canvas),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = true

        let host = FirstMouseHostingView(rootView: IslandRoot().environmentObject(model))
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: Self.canvas)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        place()
        installMonitors()
        observeModel()
    }

    func teardown() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        panel.orderOut(nil)
    }

    // MARK: Placement

    func place() {
        let target = chooseScreen()
        screen = target
        let geometry = NotchGeometry.of(target)
        if model.notch != geometry { model.notch = geometry }
        let frame = target.frame
        panel.setFrame(NSRect(x: frame.midX - Self.canvas.width / 2, y: frame.maxY - Self.canvas.height, width: Self.canvas.width, height: Self.canvas.height), display: true)
        panel.orderFrontRegardless()
        updateClickThrough(NSEvent.mouseLocation)
    }

    private func chooseScreen() -> NSScreen {
        let screens = NSScreen.screens
        if model.prefs.followPointerDisplay, let pointer = screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) {
            return pointer
        }
        return screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? screens[0]
    }

    /// The island's current target rectangle in screen coordinates, including the concave shoulders.
    private var islandRect: NSRect {
        guard let frame = screen?.frame else { return .zero }
        let size = model.islandBodySize
        let width = size.width + 2 * model.cornerRadii.top
        return NSRect(x: frame.midX - width / 2, y: frame.maxY - size.height, width: width, height: size.height)
    }

    private var hoverRect: NSRect {
        if model.isExpanded || model.alert != nil { return islandRect.insetBy(dx: -4, dy: -4) }
        // A slightly generous target around the closed notch, extended a little below it.
        let rect = islandRect
        return NSRect(x: rect.minX - 10, y: rect.minY - 6, width: rect.width + 20, height: rect.height + 6)
    }

    private func updateClickThrough(_ point: NSPoint) {
        let ignore = !islandRect.insetBy(dx: -2, dy: -2).contains(point)
        if panel.ignoresMouseEvents != ignore { panel.ignoresMouseEvents = ignore }
    }

    // MARK: Pointer

    private func installMonitors() {
        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: moves, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.pointerMoved(dragging: event.type == .leftMouseDragged) }
        }) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: moves, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.pointerMoved(dragging: event.type == .leftMouseDragged) }
            return event
        }) { monitors.append(local) }

        if let down = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.clickedOutside() }
        }) { monitors.append(down) }
        if let localDown = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.dragChangeCount = NSPasteboard(name: .drag).changeCount }
            return event
        }) { monitors.append(localDown) }

        if let up = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.dragEnded() }
        }) { monitors.append(up) }

        if let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard event.keyCode == 53, let number = event.window?.windowNumber else { return event }
            let handled = MainActor.assumeIsolated { self?.escapePressed(inWindow: number) ?? false }
            return handled ? nil : event
        }) { monitors.append(keys) }
    }

    private func escapePressed(inWindow number: Int) -> Bool {
        guard number == panel.windowNumber else { return false }
        if model.paletteOpen { model.paletteOpen = false } else { model.collapse() }
        return true
    }

    private func pointerMoved(dragging: Bool) {
        let point = NSEvent.mouseLocation
        if model.prefs.followPointerDisplay, !model.isExpanded, let screen, !NSMouseInRect(point, screen.frame, false) {
            place()
        }
        updateClickThrough(point)
        if dragging { detectFileDrag(at: point) }

        if hoverRect.contains(point) {
            cancelClose()
            if model.isExpanded {
                pointerVisited = true
            } else if model.prefs.openOnHover, !dragging, openWork == nil {
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.openWork = nil
                    guard self.hoverRect.contains(NSEvent.mouseLocation), !self.model.isExpanded else { return }
                    self.pointerVisited = true
                    self.model.expand()
                    if self.model.prefs.hapticFeedback {
                        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                    }
                }
                openWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + model.prefs.hoverDelay, execute: work)
            }
        } else {
            openWork?.cancel()
            openWork = nil
            scheduleCloseIfNeeded()
        }
    }

    private func scheduleCloseIfNeeded() {
        guard model.isExpanded, pointerVisited, model.prefs.closeOnMouseExit, !model.pinned, !model.paletteOpen, !model.fileDragActive, closeWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.closeWork = nil
            guard !self.hoverRect.contains(NSEvent.mouseLocation), !self.model.pinned, !self.model.paletteOpen, !self.panel.isKeyWindow || !self.model.wantsKeyboard else { return }
            self.model.collapse()
        }
        closeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + model.prefs.closeDelay, execute: work)
    }

    private func cancelClose() {
        closeWork?.cancel()
        closeWork = nil
    }

    /// Clicks in other apps arrive here; a click outside the open island closes it unless it's pinned.
    private func clickedOutside() {
        dragChangeCount = NSPasteboard(name: .drag).changeCount
        guard model.isExpanded, !model.pinned, !islandRect.contains(NSEvent.mouseLocation) else { return }
        model.collapse()
    }

    private func detectFileDrag(at point: NSPoint) {
        guard model.prefs.openShelfOnFileDrag, !model.fileDragActive else { return }
        let pasteboard = NSPasteboard(name: .drag)
        guard pasteboard.changeCount != dragChangeCount,
              pasteboard.types?.contains(.fileURL) == true,
              islandRect.insetBy(dx: -40, dy: -30).contains(point)
        else { return }
        model.fileDragActive = true
        pointerVisited = true
        model.expand(tab: .shelf)
    }

    private func dragEnded() {
        guard model.fileDragActive else { return }
        model.fileDragActive = false
        dragChangeCount = NSPasteboard(name: .drag).changeCount
        if !hoverRect.contains(NSEvent.mouseLocation) { scheduleCloseIfNeeded() }
    }

    // MARK: Model

    private func observeModel() {
        model.$isExpanded
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] expanded in self?.expansionChanged(expanded) }
            .store(in: &bag)

        model.$focusRequest
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.model.isExpanded else { return }
                self.panel.makeKey()
            }
            .store(in: &bag)

        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.updateClickThrough(NSEvent.mouseLocation) }
            .store(in: &bag)

        model.$prefs
            .map(\.followPointerDisplay)
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.place() }
            .store(in: &bag)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.place() }
            .store(in: &bag)
    }

    private func expansionChanged(_ expanded: Bool) {
        cancelClose()
        openWork?.cancel()
        openWork = nil
        if expanded {
            if model.wantsKeyboard { panel.makeKey() }
            if hoverRect.contains(NSEvent.mouseLocation) { pointerVisited = true }
        } else {
            pointerVisited = false
            if panel.isKeyWindow {
                // Hand the keyboard back to whatever app was in front without activating Mochy.
                panel.orderOut(nil)
                panel.orderFrontRegardless()
            }
        }
        updateClickThrough(NSEvent.mouseLocation)
    }
}
