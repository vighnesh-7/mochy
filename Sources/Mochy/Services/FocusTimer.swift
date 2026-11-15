import AppKit
import Foundation

@MainActor
final class FocusTimer: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case pomodoro, countdown, stopwatch
        var id: String { rawValue }
        var title: String {
            switch self {
            case .pomodoro: "Pomodoro"
            case .countdown: "Timer"
            case .stopwatch: "Stopwatch"
            }
        }
    }

    enum Phase: Equatable {
        case focus, shortBreak, longBreak
        var title: String {
            switch self {
            case .focus: "Focus"
            case .shortBreak: "Short Break"
            case .longBreak: "Long Break"
            }
        }
    }

    @Published var mode: Mode = .pomodoro
    @Published private(set) var phase: Phase = .focus
    @Published private(set) var round = 1
    @Published private(set) var isRunning = false
    @Published private(set) var remaining: TimeInterval = 25 * 60
    @Published private(set) var total: TimeInterval = 25 * 60
    @Published private(set) var elapsed: TimeInterval = 0

    var focusMinutes: Double = 25
    var shortBreakMinutes: Double = 5
    var longBreakMinutes: Double = 15
    var roundsBeforeLongBreak = 4
    var autoStartNext = true
    var onPhaseEnd: ((String, String) -> Void)?

    private var countdownLength: TimeInterval = 5 * 60
    private var anchor: Date?
    private var anchorValue: TimeInterval = 0
    private var ticker: Timer?

    var isActive: Bool { isRunning || (mode != .stopwatch && remaining < total && remaining > 0) || (mode == .stopwatch && elapsed > 0) }

    var progress: Double {
        switch mode {
        case .stopwatch: return 0
        default: return total > 0 ? 1 - remaining / total : 0
        }
    }

    var display: String {
        let value = mode == .stopwatch ? elapsed : remaining
        let seconds = Int(value.rounded(mode == .stopwatch ? .down : .up))
        let hours = seconds / 3600
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, (seconds % 3600) / 60, seconds % 60)
            : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    func select(_ newMode: Mode) {
        pause()
        mode = newMode
        reset()
    }

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard !isRunning else { return }
        if mode != .stopwatch, remaining <= 0 { reset() }
        isRunning = true
        anchor = Date()
        anchorValue = mode == .stopwatch ? elapsed : remaining
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    func pause() {
        tick()
        isRunning = false
        anchor = nil
        ticker?.invalidate()
        ticker = nil
    }

    func reset() {
        pause()
        elapsed = 0
        switch mode {
        case .pomodoro:
            phase = .focus
            round = 1
            setTotal(focusMinutes * 60)
        case .countdown:
            setTotal(countdownLength)
        case .stopwatch:
            setTotal(0)
        }
    }

    func setCountdown(minutes: Double) {
        pause()
        mode = .countdown
        countdownLength = minutes * 60
        setTotal(countdownLength)
    }

    func addMinute() {
        guard mode != .stopwatch else { return }
        remaining += 60
        total += 60
        if isRunning { anchor = Date(); anchorValue = remaining }
    }

    func skipPhase() {
        guard mode == .pomodoro else { return }
        advancePhase(announce: false)
    }

    private func setTotal(_ value: TimeInterval) {
        total = value
        remaining = value
    }

    private func tick() {
        guard isRunning, let anchor else { return }
        let delta = Date().timeIntervalSince(anchor)
        if mode == .stopwatch {
            elapsed = anchorValue + delta
            return
        }
        remaining = max(0, anchorValue - delta)
        if remaining == 0 { finish() }
    }

    private func finish() {
        pause()
        switch mode {
        case .countdown:
            onPhaseEnd?("Timer Done", "\(Int(total / 60)) minute timer finished")
        case .pomodoro:
            advancePhase(announce: true)
        case .stopwatch:
            break
        }
    }

    private func advancePhase(announce: Bool) {
        pause()
        let finished = phase
        if phase == .focus {
            phase = round % max(1, roundsBeforeLongBreak) == 0 ? .longBreak : .shortBreak
            setTotal((phase == .longBreak ? longBreakMinutes : shortBreakMinutes) * 60)
        } else {
            phase = .focus
            round += 1
            setTotal(focusMinutes * 60)
        }
        if announce {
            let title = finished == .focus ? "Focus Session Done" : "Break Over"
            onPhaseEnd?(title, "Up next: \(phase.title) · \(Int(total / 60)) min")
        }
        if autoStartNext && announce { start() }
    }
}
