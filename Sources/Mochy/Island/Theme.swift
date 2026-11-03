import AppKit
import SwiftUI

/// The island is always black so it reads as an extension of the camera housing.
/// Contrast figures are against #000000.
enum Island {
    static let surface = Color.black
    /// #FFFFFF, 21:1
    static let primary = Color.white
    /// White at 64% (#A3A3A3), 8.3:1
    static let secondary = Color.white.opacity(0.64)
    /// White at 46% (#757575), 4.6:1 — captions and timestamps only
    static let tertiary = Color.white.opacity(0.46)
    /// Card fill, white at 7%
    static let card = Color.white.opacity(0.07)
    static let cardHover = Color.white.opacity(0.11)
    static let hairline = Color.white.opacity(0.08)

    static let focus = Color(red: 1.0, green: 0.62, blue: 0.04) // #FF9F0A
    static let positive = Color(red: 0.19, green: 0.82, blue: 0.35) // #30D158
    static let warning = Color(red: 1.0, green: 0.27, blue: 0.23) // #FF453A
    static let info = Color(red: 0.04, green: 0.52, blue: 1.0) // #0A84FF

    static func spring(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.16) : .spring(response: 0.42, dampingFraction: 0.82, blendDuration: 0.1)
    }

    static func numerals(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    /// The body sits inset by `topRadius` on each side; the concave shoulders flare into the menu bar.
    func path(in rect: CGRect) -> Path {
        let top = min(topRadius, rect.width / 4)
        let bottom = min(bottomRadius, (rect.width - 2 * top) / 2, rect.height - top)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top, y: rect.minY + top), control: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY), control: CGPoint(x: rect.minX + top, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom), control: CGPoint(x: rect.maxX - top, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// A rounded card inside the expanded island.
struct IslandCard<Content: View>: View {
    var padding: CGFloat = 12
    var fillHeight = true
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Island.card))
    }
}

private struct ClickHapticKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var clickHaptic: Bool {
        get { self[ClickHapticKey.self] }
        set { self[ClickHapticKey.self] = newValue }
    }
}

func hapticClick() {
    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
}

func hapticHover() {
    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
}

/// Icon button sized to the 28 pt desktop target, with a hover state and a spoken label.
struct IslandIconButton: View {
    let symbol: String
    let label: String
    var tint: Color = Island.secondary
    var active = false
    var size: CGFloat = 28
    let action: () -> Void
    @Environment(\.clickHaptic) private var clickHaptic
    @State private var hovering = false

    var body: some View {
        Button {
            if clickHaptic { hapticClick() }
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(active ? Color.black : (hovering ? Island.primary : tint))
                .frame(width: size, height: size)
                .background(Circle().fill(active ? Island.primary : (hovering ? Island.cardHover : Color.clear)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(Island.tertiary)
    }
}

/// A thin capsule meter.
struct Meter: View {
    var value: Double
    var tint: Color = Island.primary
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule().fill(tint).frame(width: max(height, proxy.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: height)
    }
}

struct Ring: View {
    var progress: Double
    var tint: Color
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// Bars that move while media plays. They are decorative and hold still under Reduce Motion.
struct PlaybackBars: View {
    var playing: Bool
    var tint: Color
    var barCount = 4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !playing || reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0 ..< barCount, id: \.self) { index in
                    let phase = sin(t * (5.2 + Double(index) * 1.3) + Double(index) * 1.7)
                    let level = playing && !reduceMotion ? 0.35 + 0.65 * abs(phase) : (playing ? 0.7 : 0.25)
                    Capsule().fill(tint).frame(width: 3, height: max(3, 14 * level))
                }
            }
            .frame(height: 14)
        }
        .accessibilityHidden(true)
    }
}

func batteryColor(_ vitals: BatteryVitals) -> Color {
    if vitals.isCharging || vitals.isPluggedIn { return Island.positive }
    if vitals.percent <= 10 { return Island.warning }
    if vitals.percent <= 20 { return Island.focus }
    return Island.primary
}

func batterySymbol(_ vitals: BatteryVitals) -> String {
    if vitals.isCharging { return "battery.100percent.bolt" }
    switch vitals.percent {
    case ..<13: return "battery.0percent"
    case ..<38: return "battery.25percent"
    case ..<63: return "battery.50percent"
    case ..<88: return "battery.75percent"
    default: return "battery.100percent"
    }
}
