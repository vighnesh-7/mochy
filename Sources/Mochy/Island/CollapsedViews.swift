import SwiftUI

/// The collapsed island: either bare over the notch, two "ears" for a live activity, or an alert banner.
struct CollapsedIsland: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if let alert = model.alert {
                AlertBanner(alert: alert)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            } else if let activity = model.activity {
                ActivityEars(activity: activity, timer: model.timer, downloads: model.downloads, battery: model.battery)
                    .transition(.opacity)
            } else {
                Color.clear
            }
        }
    }
}

private struct ActivityEars: View {
    @EnvironmentObject var model: AppModel
    let activity: LiveActivity
    @ObservedObject var timer: FocusTimer
    @ObservedObject var downloads: DownloadMonitor
    @ObservedObject var battery: BatteryMonitor

    var body: some View {
        let scale = model.closedPillFactor
        HStack(spacing: 0) {
            leading.frame(width: model.earWidth(activity), alignment: .leading)
            Spacer(minLength: model.notch.width * scale)
            trailing.frame(width: model.earWidth(activity), alignment: .trailing)
        }
        .frame(height: max(22, model.notch.height + CGFloat(model.prefs.activityHeightExtra)))
        .padding(.leading, 12 * scale)
        .padding(.trailing, 18 * scale)
        .foregroundStyle(Island.primary)
    }

    @ViewBuilder private var leading: some View {
        switch activity {
        case .media:
            Artwork(image: model.nowPlaying.artwork, fallback: "music.note", tint: model.nowPlaying.accent)
                .frame(width: model.notch.height - 10, height: model.notch.height - 10)
        case .timer:
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                HStack(spacing: 5) {
                    Ring(progress: timer.progress, tint: Island.focus, lineWidth: 2.5).frame(width: 14, height: 14)
                    Text(timer.display).font(Island.numerals(12)).foregroundStyle(Island.primary)
                        .contentTransition(.numericText())
                        .monospacedDigit()
                }
            }
        case .download:
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Image(systemName: downloadSymbol(downloads.primary?.kind))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Island.info)
            }
        case .volume:
            HStack(spacing: 6) {
                Image(systemName: model.volume.muted || model.volume.level == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(model.volume.muted ? "Mute" : "\(Int(model.volume.level * 100))%")
                    .font(Island.numerals(12))
            }
        case .brightness:
            HStack(spacing: 6) {
                Image(systemName: "sun.max.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(Island.focus)
                Text("\(Int(model.brightness.level * 100))%").font(Island.numerals(12))
            }
        case .caffeine:
            Image(systemName: "cup.and.saucer.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(Island.focus)
        case .charging:
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Image(systemName: "bolt.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Island.positive)
            }
        }
    }

    @ViewBuilder private var trailing: some View {
        switch activity {
        case .media:
            PlaybackBars(playing: model.nowPlaying.isPlaying, tint: model.nowPlaying.accent)
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .timer:
            Text(timer.mode.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Island.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .download:
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                DownloadReadout(item: downloads.primary)
            }
            .foregroundStyle(Island.info)
            .frame(maxWidth: .infinity, alignment: .trailing)
        case .volume:
            Meter(value: Double(model.volume.level), tint: Island.primary, height: 6)
                .frame(width: 72)
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .brightness:
            Meter(value: Double(model.brightness.level), tint: Color.white, height: 6)
                .frame(width: 72)
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .caffeine:
            Text(model.caffeine.endsAt == nil ? "On" : model.caffeine.remainingDescription)
                .font(Island.numerals(11)).foregroundStyle(Island.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .charging:
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text("\(battery.vitals.percent)%")
                    .font(Island.numerals(11))
                    .foregroundStyle(Island.positive)
                    .contentTransition(.numericText())
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct AlertBanner: View {
    @EnvironmentObject var model: AppModel
    let alert: IslandAlert

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: model.notch.height)
            HStack(spacing: 12) {
                leadingVisual.frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Island.primary).lineLimit(1)
                    if !alert.subtitle.isEmpty {
                        Text(alert.subtitle).font(.system(size: 11)).foregroundStyle(Island.secondary).lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if let action = alert.action { model.perform(action) }
                }
                Spacer(minLength: 8)
                if alert.style == .track {
                    PlaybackBars(playing: model.nowPlaying.isPlaying, tint: alert.tint)
                }
                if let title = alert.actionTitle, let action = alert.action {
                    Button(title) { model.perform(action) }
                        .buttonStyle(PillButtonStyle(tint: alert.tint == .white ? Island.primary : alert.tint))
                }
                IslandIconButton(symbol: "xmark", label: "Dismiss", tint: Island.tertiary, size: 22) { model.dismissAlert() }
            }
            .padding(.horizontal, 22)
            .frame(height: 62)
            .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder private var leadingVisual: some View {
        if alert.style == .track {
            Artwork(image: model.nowPlaying.artwork, fallback: "music.note", tint: alert.tint)
        } else {
            Image(systemName: alert.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(alert.tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Circle().fill(alert.tint.opacity(0.18)))
        }
    }
}

private func downloadSymbol(_ kind: ActiveDownload.Kind?) -> String {
    switch kind {
    case .airdrop: "arrow.left.arrow.right"
    case .usb: "externaldrive.fill"
    case .transfer: "arrow.left.arrow.right"
    default: "arrow.down"
    }
}

private struct DownloadReadout: View {
    let item: ActiveDownload?

    var body: some View {
        if let item {
            if let fraction = item.fraction, fraction > 0.005 || item.bytes == 0 {
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(Island.numerals(11))
                    .contentTransition(.numericText())
                    .monospacedDigit()
            } else if item.bytes > 0 {
                Text(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file))
                    .font(Island.numerals(11))
                    .monospacedDigit()
            } else {
                Image(systemName: "ellipsis").font(.system(size: 11, weight: .bold))
            }
        }
    }
}

struct Artwork: View {
    let image: NSImage?
    let fallback: String
    let tint: Color

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: fallback)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(tint)
            }
        }
        .id(image.map(ObjectIdentifier.init))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

struct PillButtonStyle: ButtonStyle {
    var tint: Color = Island.primary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(configuration.isPressed ? 0.8 : 1)))
    }
}
