import SwiftUI

struct HomePanel: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let cards = Array(model.prefs.homeCards.prefix(4))
        if cards.isEmpty {
            EmptyState(symbol: "square.grid.2x2", title: "No Home Cards", message: "Choose cards in Settings › Home.")
        } else {
            GeometryReader { proxy in
                let spacing: CGFloat = 10
                let totalWeight = cards.map(\.weight).reduce(0, +)
                let available = proxy.size.width - spacing * CGFloat(cards.count - 1)
                HStack(spacing: spacing) {
                    ForEach(cards) { card in
                        HomeCard(card: card).frame(width: available * card.weight / totalWeight)
                    }
                }
            }
        }
    }
}

private struct HomeCard: View {
    @EnvironmentObject var model: AppModel
    let card: HomeCardID

    var body: some View {
        switch card {
        case .nowPlaying: NowPlayingCard(media: model.nowPlaying)
        case .calendar: TodayCard(calendar: model.calendar)
        case .controls: ControlsCard(caffeine: model.caffeine, timer: model.timer)
        case .todo: TodoCard(todo: model.todo)
        case .battery: BatteryCard(battery: model.battery)
        case .system: BatteryCard(battery: model.battery)
        case .weather: WeatherCard(weather: model.weather)
        }
    }
}

// MARK: Now Playing

struct NowPlayingCard: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var media: NowPlayingService

    var body: some View {
        IslandCard {
            if media.hasMedia {
                GeometryReader { card in
                    // The text column keeps at least 112 pt for the three transport buttons.
                    let side = max(0, min(card.size.height, card.size.width - 124))
                    HStack(spacing: 12) {
                        Button { media.openSourceApp() } label: {
                            Artwork(image: media.artwork, fallback: "music.note", tint: media.accent)
                                .frame(width: side, height: side)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(alignment: .bottomTrailing) {
                                    if let icon = media.appIcon {
                                        Image(nsImage: icon).resizable().frame(width: 22, height: 22).offset(x: 5, y: 5)
                                    }
                                }
                                .scaleEffect(media.isPlaying ? 1 : 0.94)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: media.isPlaying)
                        }
                        .buttonStyle(.plain)
                        .help("Open \(media.appName)")
                        .accessibilityLabel("Open \(media.appName)")
                        .frame(maxHeight: .infinity, alignment: .center)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(media.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Island.primary).lineLimit(1)
                            Text(media.artist.isEmpty ? media.appName : media.artist).font(.system(size: 12)).foregroundStyle(Island.secondary).lineLimit(1)
                            Spacer(minLength: 6)
                            Scrubber(media: media)
                            HStack(spacing: 4) {
                                Spacer(minLength: 0)
                                IslandIconButton(symbol: "backward.fill", label: "Previous Track", tint: Island.primary) { media.previous() }
                                IslandIconButton(symbol: media.isPlaying ? "pause.fill" : "play.fill", label: media.isPlaying ? "Pause" : "Play", tint: Island.primary, size: 36) { media.playPause() }
                                IslandIconButton(symbol: "forward.fill", label: "Next Track", tint: Island.primary) { media.next() }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            } else {
                EmptyState(symbol: "music.note", title: "Nothing Playing", message: media.bridgeError ?? "Play something in Music, Spotify, or a browser tab.")
            }
        }
        .background {
            if model.prefs.artworkTint, media.hasMedia {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [media.accent.opacity(0.28), media.accent.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .animation(.easeInOut(duration: 0.6), value: media.accent)
            }
        }
    }
}

private struct Scrubber: View {
    @ObservedObject var media: NowPlayingService
    @State private var dragFraction: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let position = media.position(at: context.date)
            let fraction = dragFraction ?? (media.duration > 0 ? position / media.duration : 0)
            VStack(spacing: 3) {
                GeometryReader { proxy in
                    Meter(value: fraction, tint: Island.primary, height: dragFraction == nil ? 4 : 6)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard media.duration > 0 else { return }
                                    dragFraction = min(max(value.location.x / proxy.size.width, 0), 1)
                                }
                                .onEnded { _ in
                                    if let dragFraction, media.duration > 0 { media.seek(to: dragFraction * media.duration) }
                                    dragFraction = nil
                                }
                        )
                }
                .frame(height: 10)
                HStack {
                    Text(timeText(fraction * media.duration))
                    Spacer()
                    Text(media.duration > 0 ? "-" + timeText(max(0, media.duration - fraction * media.duration)) : "Live")
                }
                .font(Island.numerals(10, weight: .medium))
                .foregroundStyle(Island.tertiary)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue(timeText(media.position()))
    }

    private func timeText(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = Int(seconds)
        return total >= 3600 ? String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60) : String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: Today

struct TodayCard: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var calendar: CalendarService

    var body: some View {
        IslandCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "Today")
                    Spacer()
                    Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day()))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Island.focus)
                }
                CalendarAccessGate(calendar: calendar) {
                    let events = calendar.today.filter { $0.end > Date() && (model.prefs.showAllDayEvents || !$0.isAllDay) }
                    if events.isEmpty {
                        Text("No more events today").font(.system(size: 12)).foregroundStyle(Island.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(events) { EventRow(event: $0, calendar: calendar) }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct EventRow: View {
    let event: AgendaEvent
    let calendar: CalendarService
    var compact = true

    var body: some View {
        let ended = event.end <= Date()
        HStack(spacing: 8) {
            Capsule().fill(event.color).frame(width: 3, height: compact ? 26 : 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Island.primary).lineLimit(1)
                Text(timeRange + (compact ? "" : event.location.map { " · \($0)" } ?? ""))
                    .font(.system(size: 10.5))
                    .foregroundStyle(event.isHappeningNow ? Island.focus : Island.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if let url = event.joinURL, !ended, event.start.timeIntervalSinceNow < 15 * 60 {
                Button("Join") { NSWorkspace.shared.open(url) }.buttonStyle(PillButtonStyle(tint: Island.positive))
            }
        }
        .opacity(ended ? 0.5 : 1)
        .contentShape(Rectangle())
        .onTapGesture { calendar.open(event) }
        .accessibilityElement(children: .combine)
    }

    private var timeRange: String {
        if event.isAllDay { return "All day" }
        if event.isHappeningNow { return "Now · until \(event.end.formatted(date: .omitted, time: .shortened))" }
        return "\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))"
    }
}

struct CalendarAccessGate<Content: View>: View {
    @ObservedObject var calendar: CalendarService
    @ViewBuilder var content: Content

    var body: some View {
        switch calendar.eventAccess {
        case .granted:
            content
        case .unknown:
            VStack(alignment: .leading, spacing: 8) {
                Text("See today’s events and get a heads-up before meetings.").font(.system(size: 11.5)).foregroundStyle(Island.secondary)
                Button("Allow Calendar Access") { calendar.requestAccess() }.buttonStyle(PillButtonStyle())
            }
            .frame(maxHeight: .infinity)
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Text("Calendar access is off for Mochy.").font(.system(size: 11.5)).foregroundStyle(Island.secondary)
                Button("Open Privacy Settings") { calendar.openPrivacySettings() }.buttonStyle(PillButtonStyle())
            }
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: Controls

struct ControlsCard: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var caffeine: CaffeineService
    @ObservedObject var timer: FocusTimer

    var body: some View {
        IslandCard(padding: 8) {
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    ControlTile(symbol: "cup.and.saucer.fill", title: caffeine.isActive ? caffeine.remainingDescription : "Caffeine", tint: Island.focus, active: caffeine.isActive) {
                        model.toggleCaffeine()
                    }
                    .contextMenu {
                        ForEach(CaffeineDuration.allCases) { duration in
                            Button(duration.title) { model.startCaffeine(duration) }
                        }
                        if caffeine.isActive { Button("Turn Off") { caffeine.stop() } }
                    }
                    ControlTile(symbol: "timer", title: timer.isActive ? timer.display : "Focus", tint: Island.focus, active: timer.isRunning) {
                        model.togglePomodoro()
                    }
                }
                GridRow {
                    ControlTile(symbol: model.pinned ? "pin.fill" : "pin", title: model.pinned ? "Pinned" : "Pin", tint: Island.info, active: model.pinned) {
                        model.pinned.toggle()
                    }
                    ControlTile(symbol: "eyedropper", title: "Color", tint: Island.primary, active: false) {
                        model.pickColor()
                    }
                }
            }
        }
    }
}

struct ControlTile: View {
    let symbol: String
    let title: String
    let tint: Color
    let active: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(active ? Color.black : Island.primary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(active ? tint : Color.white.opacity(hovering ? 0.18 : 0.12)))
                Text(title)
                    .font(Island.numerals(10.5, weight: .medium))
                    .foregroundStyle(active ? Island.primary : Island.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

// MARK: Small cards

struct TodoCard: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var todo: TodoStore

    var body: some View {
        IslandCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    SectionLabel(text: "To-Do")
                    Spacer()
                    Text("\(todo.openCount) left").font(Island.numerals(11, weight: .medium)).foregroundStyle(Island.tertiary)
                }
                let open = todo.ordered.filter { !$0.done }.prefix(4)
                if open.isEmpty {
                    Text("All done").font(.system(size: 12)).foregroundStyle(Island.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(Array(open)) { item in
                        TodoRow(item: item, todo: todo)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .onTapGesture(count: 2) { model.expand(tab: .todo, keyboard: true) }
    }
}

struct BatteryCard: View {
    @ObservedObject var battery: BatteryMonitor

    var body: some View {
        let vitals = battery.vitals
        IslandCard {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "Battery")
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(vitals.percent)").font(Island.numerals(30, weight: .bold)).foregroundStyle(batteryColor(vitals))
                    Text("%").font(.system(size: 14, weight: .semibold)).foregroundStyle(Island.secondary)
                    Spacer()
                    Image(systemName: batterySymbol(vitals)).font(.system(size: 18)).foregroundStyle(batteryColor(vitals))
                }
                Text(vitals.hasBattery ? vitals.timeDescription : "No battery").font(.system(size: 11)).foregroundStyle(Island.secondary).lineLimit(1)
                if let health = vitals.healthPercent {
                    Text("Health \(health)%" + (vitals.cycleCount.map { " · \($0) cycles" } ?? ""))
                        .font(.system(size: 10.5)).foregroundStyle(Island.tertiary).lineLimit(1)
                }
            }
        }
    }
}

struct WeatherCard: View {
    @ObservedObject var weather: WeatherService

    var body: some View {
        IslandCard {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "Weather")
                Spacer(minLength: 0)
                if weather.needsPermission {
                    Text("Allow location access for Mochy in Privacy & Security settings.").font(.system(size: 11)).foregroundStyle(Island.secondary)
                } else {
                    Image(systemName: weather.symbol).symbolRenderingMode(.multicolor).font(.system(size: 24))
                    Text(weather.temperature ?? "—").font(Island.numerals(26, weight: .bold)).foregroundStyle(Island.primary)
                    Text(weather.condition).font(.system(size: 11)).foregroundStyle(Island.secondary).lineLimit(1)
                    Text(weather.range).font(Island.numerals(10.5, weight: .medium)).foregroundStyle(Island.tertiary)
                }
            }
        }
        .onAppear { weather.refreshIfStale() }
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 20, weight: .semibold)).foregroundStyle(Island.tertiary)
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Island.primary)
            Text(message).font(.system(size: 11.5)).foregroundStyle(Island.secondary).multilineTextAlignment(.center).lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
    }
}
