import SwiftUI

struct ExpandedIsland: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection
    @State private var forward = true

    var body: some View {
        VStack(spacing: 0) {
            header.frame(height: model.headerHeight)
            ZStack {
                CalendarPanel(calendar: model.calendar)
                    .opacity(model.tab == .calendar ? 1 : 0)
                    .allowsHitTesting(model.tab == .calendar)
                    .accessibilityHidden(model.tab != .calendar)
                if model.tab != .calendar {
                    TabContent(tab: model.tab)
                        .id(model.tab)
                        .transition(reduceMotion ? .opacity : .push(from: forward ? .trailing : .leading))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .padding(.horizontal, 12)
            .padding(.top, AppModel.expandedContentTop)
            .padding(.bottom, AppModel.expandedContentBottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .overlay {
            if model.paletteOpen {
                CommandPalette()
                    .padding(.top, model.headerHeight)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .animation(Island.spring(reduceMotion), value: model.paletteOpen)
    }

    private var sideWidth: CGFloat {
        let notch = model.notch.hasNotch ? model.notch.width + 16 : 120
        return max(120, (model.prefs.panelSize.width - notch) / 2 - 14)
    }

    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: CGFloat(model.prefs.tabIconGap)) {
                let strip = headerTabs
                ForEach(strip.shown) { item in tabButton(item) }
                if strip.overflow {
                    IslandIconButton(symbol: "ellipsis", label: "More Tabs") {
                        model.paletteOpen = true
                        model.focusRequest = UUID()
                    }
                }
            }
            .animation(Island.spring(reduceMotion), value: model.tab)
            .frame(width: sideWidth, alignment: .leading)

            Spacer(minLength: 0)
            if !model.notch.hasNotch {
                Text(model.tab.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Island.secondary)
                    .transition(.opacity)
                    .id(model.tab)
                Spacer(minLength: 0)
            }

            HStack(spacing: 2) {
                IslandIconButton(symbol: "magnifyingglass", label: "Command Palette \(shortcut(.commandPalette))") {
                    model.paletteOpen.toggle()
                    if model.paletteOpen { model.focusRequest = UUID() }
                }
                IslandIconButton(
                    symbol: model.prefs.alwaysShowNowPlaying ? "music.note" : "music.note.slash",
                    label: model.prefs.alwaysShowNowPlaying ? "Hide Now Playing on the Notch" : "Show Now Playing on the Notch",
                    active: model.prefs.alwaysShowNowPlaying
                ) {
                    model.prefs.alwaysShowNowPlaying.toggle()
                }
                CaffeineHeaderButton(caffeine: model.caffeine) {
                    model.toggleCaffeine()
                }
                IslandIconButton(
                    symbol: "dock.rectangle",
                    label: model.prefs.dockShortcutsEnabled ? "Hide Dock Shortcuts" : "Show Dock Shortcuts",
                    active: model.prefs.dockShortcutsEnabled
                ) {
                    model.prefs.dockShortcutsEnabled.toggle()
                }
                IslandIconButton(symbol: model.pinned ? "pin.fill" : "pin", label: model.pinned ? "Unpin the Island" : "Pin the Island Open", active: model.pinned) {
                    model.pinned.toggle()
                }
                IslandIconButton(symbol: "gearshape.fill", label: "Settings \(shortcut(.settings))") {
                    model.collapse()
                    model.openSettings?()
                }
                IslandIconButton(symbol: "power", label: "Quit Mochy") {
                    NSApp.terminate(nil)
                }
            }
            .frame(width: sideWidth, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
    }

    /// Tabs that fit beside the notch at the current icon gap; the current tab always stays in view.
    private var headerTabs: (shown: [TabID], overflow: Bool) {
        let tabs = model.visibleTabs
        let gap = CGFloat(model.prefs.tabIconGap)
        let cell = 26 + gap
        let capacity = max(1, Int((sideWidth + gap) / max(cell, 1)))
        guard tabs.count > capacity else { return (tabs, false) }
        var shown = Array(tabs.prefix(max(capacity - 1, 1)))
        if !shown.contains(model.tab), let last = shown.indices.last { shown[last] = model.tab }
        return (shown, true)
    }

    private func tabButton(_ item: TabID) -> some View {
        let selected = item == model.tab
        return Button {
            select(item)
        } label: {
            Image(systemName: item.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? Island.primary : Island.secondary)
                .frame(width: 26 + CGFloat(model.prefs.tabIconGap), height: 22 + CGFloat(model.prefs.tabIconGap) * 0.5)
                .background {
                    if selected {
                        Capsule()
                            .fill(Color.white.opacity(0.16))
                            .matchedGeometryEffect(id: "tabPill", in: selection)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(item.title)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func select(_ item: TabID) {
        guard item != model.tab else { return }
        let order = model.visibleTabs
        forward = (order.firstIndex(of: item) ?? 0) > (order.firstIndex(of: model.tab) ?? 0)
        // The outgoing view reads `forward` on the next pass, so the tab change follows it.
        DispatchQueue.main.async {
            withAnimation(Island.spring(reduceMotion)) { model.tab = item }
        }
    }

    private func shortcut(_ id: ShortcutID) -> String {
        model.prefs.shortcuts[id].map { "(\($0.display))" } ?? ""
    }
}

private struct CaffeineHeaderButton: View {
    @ObservedObject var caffeine: CaffeineService
    let action: () -> Void

    var body: some View {
        IslandIconButton(
            symbol: caffeine.isActive ? "cup.and.saucer.fill" : "cup.and.saucer",
            label: caffeine.isActive ? "Turn Off Caffeine" : "Keep This Mac Awake",
            active: caffeine.isActive,
            action: action
        )
    }
}

private struct TabContent: View {
    @EnvironmentObject var model: AppModel
    let tab: TabID

    var body: some View {
        switch tab {
        case .home: HomePanel()
        case .nowPlaying: NowPlayingCard(media: model.nowPlaying)
        case .shelf: ShelfPanel(shelf: model.shelf)
        case .clipboard: ClipboardPanel(clipboard: model.clipboard)
        case .todo: TodoPanel(todo: model.todo)
        case .timer: TimerPanel(timer: model.timer)
        case .calendar: CalendarPanel(calendar: model.calendar)
        case .stats: SystemPanel(battery: model.battery)
        case .notes: NotesPanel(notes: model.notes)
        case .calculator: CalculatorPanel(calculator: model.calculator)
        case .quickSearch: SearchPanel()
        case .launcher: LauncherPanel(launcher: model.launcher)
        case .emoji: EmojiPanel()
        case .mirror: MirrorPanel()
        }
    }
}

struct CommandPalette: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    @State private var index = 0
    @FocusState private var focused: Bool

    private var results: [PaletteCommand] {
        let all = model.paletteCommands
        guard !query.isEmpty else { return all }
        return all.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Island.secondary)
                TextField("Type a command", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(Island.primary)
                    .focused($focused)
                    .onSubmit(runSelected)
                    .onChange(of: query) { _, _ in index = 0 }
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Island.card))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { offset, command in
                            Button {
                                index = offset
                                runSelected()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: command.symbol).frame(width: 18).foregroundStyle(Island.secondary)
                                    Text(command.title).foregroundStyle(Island.primary)
                                    Spacer()
                                    Text(command.detail).font(.system(size: 11)).foregroundStyle(Island.tertiary)
                                }
                                .font(.system(size: 12.5))
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(offset == index ? Color.white.opacity(0.14) : .clear))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(offset)
                        }
                    }
                }
                .onChange(of: index) { _, value in proxy.scrollTo(value) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Island.surface)
        .onAppear { focused = true }
        .onChange(of: model.focusRequest) { _, _ in focused = true }
        .onKeyPress(.downArrow) {
            index = min(index + 1, max(results.count - 1, 0))
            return .handled
        }
        .onKeyPress(.upArrow) {
            index = max(index - 1, 0)
            return .handled
        }
    }

    private func runSelected() {
        guard results.indices.contains(index) else { return }
        let command = results[index]
        model.paletteOpen = false
        command.run()
    }
}
