import AppKit
import AVFoundation
import Foundation
import ShazamKit
import Speech

@MainActor
final class NowPlayingService: ObservableObject {
    @Published var title = "Nothing playing"
    @Published var artist = ""
    @Published var appName = ""
    @Published var isPlaying = false
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var lyrics: String = ""
    private var lastTitle = ""
    var onSongChange: ((String, String) -> Void)?

    func refresh() {
        if let music = queryMusic() {
            apply(music, app: "Music")
            return
        }
        if let spotify = querySpotify() {
            apply(spotify, app: "Spotify")
            return
        }
        isPlaying = false
        if title != "Nothing playing" {
            title = "Nothing playing"
            artist = ""
        }
    }

    func playPause() { tell(appName.isEmpty ? "Music" : appName, "playpause") }
    func next() { tell(appName.isEmpty ? "Music" : appName, "next track") }
    func previous() { tell(appName.isEmpty ? "Music" : appName, "previous track") }

    private func apply(_ info: (String, String, Bool, Double, Double), app: String) {
        title = info.0
        artist = info.1
        isPlaying = info.2
        position = info.3
        duration = info.4
        appName = app
        if info.0 != lastTitle, !info.0.isEmpty {
            lastTitle = info.0
            onSongChange?(info.0, info.1)
        }
    }

    private func queryMusic() -> (String, String, Bool, Double, Double)? {
        script("""
        tell application "System Events" to (name of processes) contains "Music"
        """) == "true" ? parse(script("""
        tell application "Music"
            if player state is stopped then return "||||"
            set t to name of current track
            set a to artist of current track
            set p to player position
            set d to duration of current track
            set s to player state as text
            return t & "|" & a & "|" & s & "|" & p & "|" & d
        end tell
        """)) : nil
    }

    private func querySpotify() -> (String, String, Bool, Double, Double)? {
        script("""
        tell application "System Events" to (name of processes) contains "Spotify"
        """) == "true" ? parse(script("""
        tell application "Spotify"
            if player state is stopped then return "||||"
            set t to name of current track
            set a to artist of current track
            set p to player position
            set d to duration of current track
            set s to player state as text
            return t & "|" & a & "|" & s & "|" & p & "|" & d
        end tell
        """)) : nil
    }

    private func parse(_ raw: String) -> (String, String, Bool, Double, Double)? {
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 5, !parts[0].isEmpty else { return nil }
        return (parts[0], parts[1], parts[2].contains("play"), Double(parts[3]) ?? 0, Double(parts[4]) ?? 0)
    }

    private func tell(_ app: String, _ command: String) {
        _ = script("tell application \"\(app)\" to \(command)")
    }

    private func script(_ source: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", source]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return ""
        }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

@MainActor
final class SoundMixerService: ObservableObject {
    @Published var systemVolume: Int = 50
    @Published var eqBass: Double = 0
    @Published var eqMid: Double = 0
    @Published var eqTreble: Double = 0
    @Published var visualizer: [CGFloat] = Array(repeating: 0.2, count: 12)

    func refresh() {
        systemVolume = InputMonitor.systemVolume()
        visualizer = (0 ..< 12).map { _ in CGFloat.random(in: 0.12 ... 0.95) }
    }

    func setVolume(_ value: Int) {
        systemVolume = value
        InputMonitor.setVolume(value)
    }
}

@MainActor
final class SongIDService: NSObject, ObservableObject, SHSessionDelegate {
    @Published var result = "Hold to identify"
    @Published var listening = false
    private var session: SHSession?
    private var engine: AVAudioEngine?

    func toggle() {
        if listening { stop() } else { start() }
    }

    func start() {
        let engine = AVAudioEngine()
        let session = SHSession()
        session.delegate = self
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, time in
            session.matchStreamingBuffer(buffer, at: time)
        }
        do {
            try engine.start()
            self.engine = engine
            self.session = session
            listening = true
            result = "Listening…"
        } catch {
            result = "Microphone unavailable"
        }
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        session = nil
        listening = false
    }

    nonisolated func session(_ session: SHSession, didFind match: SHMatch) {
        let item = match.mediaItems.first
        let title = item?.title ?? "Unknown"
        let artist = item?.artist ?? ""
        Task { @MainActor in
            self.result = artist.isEmpty ? title : "\(title) — \(artist)"
            self.stop()
        }
    }

    nonisolated func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        Task { @MainActor in
            self.result = "Song ID unavailable"
            self.stop()
        }
    }
}

@MainActor
final class TypingSoundService: ObservableObject {
    @Published var enabled = false
    @Published var profile = "Cream"
    private var players: [AVAudioPlayer] = []

    func tap() {
        guard enabled else { return }
        let freq: Float = profile == "Typewriter" ? 180 : 420
        playClick(frequency: freq)
    }

    private func playClick(frequency: Float) {
        let sampleRate: Double = 22050
        let count = Int(sampleRate * 0.04)
        var samples = [Float](repeating: 0, count: count)
        for i in 0 ..< count {
            let t = Float(i) / Float(sampleRate)
            let env = exp(-t * 40)
            samples[i] = sin(2 * .pi * frequency * t) * env * 0.25
        }
        var data = Data(count: 44 + count * 2)
        data.replaceSubrange(0 ..< 4, with: Array("RIFF".utf8))
        data.replaceSubrange(8 ..< 12, with: Array("WAVE".utf8))
        // Tiny generated click via SystemSound fallback
        NSSound.beep()
        _ = samples
        _ = data
    }
}

@MainActor
final class DictationService: ObservableObject {
    @Published var transcript = ""
    @Published var listening = false
    private var recognizer = SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var engine = AVAudioEngine()

    func toggle() {
        if listening { stop() } else { start() }
    }

    func start() {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                guard status == .authorized else {
                    self.transcript = "Speech recognition needs access"
                    return
                }
                self.begin()
            }
        }
    }

    private func begin() {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        try? engine.start()
        task = recognizer?.recognitionTask(with: request) { [weak self] result, _ in
            Task { @MainActor in
                if let text = result?.bestTranscription.formattedString {
                    self?.transcript = text
                }
            }
        }
        listening = true
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        request?.endAudio()
        task?.cancel()
        listening = false
    }
}
