import AppKit
import SwiftUI

final class IslandWindowController: NSWindowController {
    private var hosting: NSHostingView<AnyView>?
    private var notchCover: NSWindow?
    private weak var model: AppModel?

    convenience init(model: AppModel) {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.hidesOnDeactivate = false
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = true
        window.animationBehavior = .utilityWindow
        window.acceptsMouseMovedEvents = true
        window.sharingType = model.prefs.keepPillOutOfCaptures || model.prefs.hideFromZoomMeetTeamsOBS ? .none : .readOnly
        self.init(window: window)
        self.model = model
        let root = IslandRootView()
            .environmentObject(model)
        let host = NSHostingView(rootView: AnyView(root))
        host.frame = window.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        window.contentView = host
        hosting = host
        reposition()
        NotificationCenter.default.addObserver(self, selector: #selector(reposition), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc func reposition() {
        guard let window, let screen = NSScreen.main else { return }
        let frame = screen.frame
        let width: CGFloat = max(760, (model?.prefs.panelWidth ?? 640) + 80)
        let height: CGFloat = max(460, (model?.prefs.panelHeight ?? 320) + 80)
        window.sharingType = (model?.prefs.keepPillOutOfCaptures == true || model?.prefs.hideFromZoomMeetTeamsOBS == true) ? .none : .readOnly
        let x = frame.midX - width / 2
        let y = frame.maxY - height - 2
        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        updateNotchCover(screen: screen)
    }

    func updateNotchCover(screen: NSScreen) {
        guard model?.hideNotchBezel == true else {
            notchCover?.orderOut(nil)
            return
        }
        if notchCover == nil {
            let cover = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            cover.isOpaque = true
            cover.backgroundColor = .black
            cover.level = .statusBar
            cover.ignoresMouseEvents = true
            cover.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            notchCover = cover
        }
        let menuHeight = screen.frame.maxY - screen.visibleFrame.maxY
        let width: CGFloat = 220
        notchCover?.setFrame(
            NSRect(x: screen.frame.midX - width / 2, y: screen.visibleFrame.maxY, width: width, height: max(menuHeight, 32)),
            display: true
        )
        notchCover?.orderFrontRegardless()
    }
}

struct IslandRootView: View {
    @EnvironmentObject var model: AppModel
    @State private var hover = false

    var body: some View {
        VStack(spacing: 0) {
            if !model.hidden {
                IslandView(hovering: hover)
                    .onHover { inside in
                        hover = inside
                        if inside, model.prefs.hoverToOpen || model.prefs.expandOnHover {
                            DispatchQueue.main.asyncAfter(deadline: .now() + model.prefs.hoverDelay) {
                                if hover { model.expand() }
                            }
                        } else if !inside, model.prefs.autoCollapse, model.islandState == .expanded, !model.paletteOpen {
                            DispatchQueue.main.asyncAfter(deadline: .now() + model.prefs.collapseDelay) {
                                if !hover, model.islandState == .expanded {
                                    model.collapse()
                                }
                            }
                        }
                    }
                    .contextMenu {
                        Button("Settings…") { model.settingsOpen = true }
                        Button("Command Palette") { model.paletteOpen = true }
                        Button(model.hidden ? "Show Mochy" : "Hide Mochy") { model.hidden.toggle() }
                        Divider()
                        Button("Quit Mochy") { NSApp.terminate(nil) }
                    }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 2)
        .overlay(alignment: .top) {
            if model.paletteOpen, model.prefs.commandPaletteButton || model.paletteOpen {
                CommandPalette()
                    .padding(.top, 86)
            }
        }
        .overlay(alignment: .bottom) {
            if model.hud.visible {
                HUDBanner()
                    .padding(.bottom, 48)
            }
        }
        .overlay(alignment: .center) {
            if model.keycaps.visible {
                Text(model.keycaps.combo)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(glass(width: 280, height: 56, corner: 14, opacity: 0.7, look: model.prefs.glassLook))
                    .foregroundStyle(.white)
            }
        }
    }
}

struct HUDBanner: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: model.hud.symbol)
            Text(model.hud.title)
            ProgressView(value: Double(model.hud.value), total: 100)
                .tint(model.prefs.colorCodedVolume ? (model.hud.value < 20 ? .red : model.hud.value < 60 ? .orange : .green) : .white)
                .frame(width: 120)
            Text("\(model.hud.value)%").monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(width: 320, height: 44)
        .background(glass(width: 320, height: 44, corner: 22, opacity: model.prefs.glassOpacity, look: model.prefs.glassLook))
    }
}

struct NotchBodyShape: Shape {
    var expanded: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = expanded ? min(28, rect.height / 2) : rect.height / 2
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: r, height: r))
        return path
    }
}
