import SwiftUI

struct IslandView: View {
    @EnvironmentObject var model: AppModel
    var hovering: Bool

    private var expanded: Bool {
        model.islandState == .expanded || model.paletteOpen
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.islandState == .transient, let island = model.transient {
                TransientView(island: island)
                    .transition(.scale.combined(with: .opacity))
            } else if expanded {
                ExpandedPanel()
                    .transition(.scale.combined(with: .opacity))
            } else {
                PillView()
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.42 / max(0.4, model.prefs.animationSpeed), dampingFraction: model.prefs.hoverDamping), value: model.islandState)
        .opacity(model.prefs.invisibleUntilHover && model.islandState == .collapsed && !hovering ? 0.02 : 1)
        .gesture(DragGesture(minimumDistance: 24).onEnded { value in
            guard model.prefs.swipeGestures else { return }
            if value.translation.height > 28, model.prefs.swipeToOpen { model.expand() }
            if value.translation.height < -28, model.prefs.swipeToDismiss { model.collapse() }
            if abs(value.translation.width) > 40, model.prefs.swipeToChangeTabs {
                let tabs = model.visibleTabs
                guard let idx = tabs.firstIndex(of: model.selectedTab) else { return }
                let next = value.translation.width < 0 ? (idx + 1) % tabs.count : (idx - 1 + tabs.count) % tabs.count
                model.expand(tab: tabs[next])
            }
            if abs(value.translation.width) > 40, model.prefs.swipeToChangeTrack, model.islandState == .collapsed {
                if value.translation.width < 0 { model.nowPlaying.next() } else { model.nowPlaying.previous() }
            }
        })
        .onTapGesture(count: model.prefs.requireDoubleClick ? 2 : 1) {
            if model.islandState == .collapsed { model.expand() }
            else { model.collapse() }
        }
    }
}

struct PillView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(Color.white.opacity(0.18)).frame(width: 8, height: 8)
            if model.nowPlaying.isPlaying {
                Image(systemName: "music.note").font(.system(size: 11, weight: .semibold))
                Text(model.prefs.lyricsOnPill ? model.nowPlaying.title : "Mochy")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            } else {
                Text(timeString)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("·")
                    .foregroundStyle(.secondary)
                Text("\(model.battery.percent)%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            if model.caffeine.isActive {
                Image(systemName: "cup.and.saucer.fill").font(.system(size: 10))
            }
            Circle().fill(Color.white.opacity(0.18)).frame(width: 8, height: 8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .frame(width: model.prefs.closedPillWidth, height: model.prefs.closedPillHeight)
        .background(glass(width: model.prefs.closedPillWidth, height: model.prefs.closedPillHeight, corner: model.prefs.closedPillHeight / 2, opacity: model.prefs.glassOpacity, look: model.prefs.glassLook))
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = model.prefs.clock24h ? "HH:mm" : "h:mm"
        return f.string(from: Date())
    }
}

struct TransientView: View {
    @EnvironmentObject var model: AppModel
    let island: TransientIsland
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: island.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(island.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(island.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                if !island.message.isEmpty {
                    Text(island.message).font(.system(size: 11)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(width: model.prefs.hudWidth * model.prefs.hudSize, height: 52 * model.prefs.hudSize)
        .background(glass(width: model.prefs.hudWidth * model.prefs.hudSize, height: 52 * model.prefs.hudSize, corner: 24, opacity: model.prefs.glassOpacity, look: model.prefs.glassLook))
    }
}

struct ExpandedPanel: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider().overlay(Color.white.opacity(0.08))
            TabHost()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: model.prefs.panelWidth, height: model.prefs.panelHeight)
        .background(glass(width: model.prefs.panelWidth, height: model.prefs.panelHeight, corner: 28, opacity: model.prefs.glassOpacity, look: model.prefs.glassLook))
        .font(.system(size: model.prefs.panelFontSize))
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                Button { model.paletteOpen.toggle() } label: {
                    Image(systemName: "magnifyingglass")
                }
                Button { model.settingsOpen = true } label: {
                    Image(systemName: "gearshape")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.8))
            .padding(14)
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(model.visibleTabs) { tab in
                    Button {
                        model.selectedTab = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.symbol)
                            if model.selectedTab == tab {
                                Text(tab.title).font(.system(size: 11, weight: .semibold))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(model.selectedTab == tab ? Color.white.opacity(0.14) : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(model.selectedTab == tab ? .white : .white.opacity(0.55))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

struct TabHost: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        Group {
            switch model.selectedTab {
            case .home: HomeTab()
            case .nowPlaying: NowPlayingTab()
            case .calendar: CalendarTab()
            case .reminders: RemindersTab()
            case .notes: NotesTab()
            case .focus: FocusTab()
            case .translate: TranslateTab()
            case .activity: ActivityTab()
            case .aiUsage: AIUsageTab()
            case .askAI: AskAITab()
            case .launcher: LauncherTab()
            case .packages: PackagesTab()
            case .files: FilesTab()
            case .clipboard: ClipboardTab()
            case .shortcuts: ShortcutsTab()
            case .calculator: CalculatorTab()
            case .quickSearch: QuickSearchTab()
            case .notifications: NotificationsTab()
            case .todo: TodoTab()
            case .cuely: CuelyTab()
            case .emoji: EmojiTab()
            case .timer: TimerTab()
            case .mirror: MirrorTab()
            case .stocks: StocksTab()
            case .homeKit: HomeKitTab()
            case .terminal: TerminalTab()
            case .soundMixer: SoundMixerTab()
            case .settings: QuickSettingsTab()
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .foregroundStyle(.white)
    }
}

func glass(width: CGFloat, height: CGFloat, corner: CGFloat, opacity: Double = 0.55, look: String = "Glass") -> some View {
    GlassPlate(width: width, height: height, corner: corner, opacity: opacity, look: look)
}

private struct GlassPlate: View {
    var width: CGFloat
    var height: CGFloat
    var corner: CGFloat
    var opacity: Double
    var look: String
    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(look == "None" || look == "Flat" ? Color.clear : Color.white.opacity(0.001))
            .background {
                if look == "None" {
                    Color.clear
                } else if look == "Flat" {
                    RoundedRectangle(cornerRadius: corner, style: .continuous).fill(Color.black.opacity(0.92))
                } else {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: corner, style: .continuous)
                                .fill(look == "Mono" ? Color.gray.opacity(opacity) : Color.black.opacity(opacity))
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(look == "None" ? 0 : 0.12), lineWidth: 1)
            )
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

struct EmptyHint: View {
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
