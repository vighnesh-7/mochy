import AVFoundation
import AVKit
import AppKit
import SwiftUI
import Vision

struct FocusTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus").font(.headline)
            HStack(spacing: 16) {
                ring("Move", model.activity.move, .green)
                ring("Type", model.activity.type, .orange)
                ring("Focus", model.focus.sessionActive ? 0.8 : model.activity.focus, .cyan)
            }
            Toggle("Focus session", isOn: Binding(
                get: { model.focus.sessionActive },
                set: { _ in model.focus.toggle() }
            ))
            Text("\(model.activity.keystrokesToday) keystrokes today").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func ring(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack {
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 8)
                Circle().trim(from: 0, to: value).stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 64, height: 64)
            Text(title).font(.caption)
        }
    }
}

struct TranslateTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Translate from", text: $model.translate.from).frame(width: 50)
                Button("Swap") { model.translate.swapLanguages() }
                TextField("to", text: $model.translate.to).frame(width: 50)
            }
            TextField("Phrase", text: $model.translate.source)
                .textFieldStyle(.plain)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                .onSubmit { model.translate.run() }
            Text(model.translate.output).frame(maxWidth: .infinity, alignment: .leading)
            Text("⌘⏎ runs it, ⌘⇧S swaps the languages").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct ActivityTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        FocusTab()
    }
}

struct AIUsageTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage from Claude, Codex, Cursor, Antigravity and Copilot, read on this Mac.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(model.aiUsage.rows) { row in
                HStack {
                    Text(row.name).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(row.detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Button("Refetch") { model.aiUsage.refresh() }
        }
        .onAppear { model.aiUsage.refresh() }
    }
}

struct AskAITab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField("Anthropic API key", text: $model.askAI.apiKey)
            TextField("Ask Claude…", text: $model.askAI.prompt)
                .onSubmit { model.askAI.send() }
            if model.askAI.busy { ProgressView() }
            ScrollView { Text(model.askAI.reply) }
        }
    }
}

struct LauncherTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search apps", text: $model.launcher.query)
                .textFieldStyle(.plain)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    ForEach(model.launcher.filtered) { app in
                        Button { model.launcher.open(app) } label: {
                            VStack {
                                Image(nsImage: app.icon).resizable().frame(width: 32, height: 32)
                                Text(app.name).font(.caption2).lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct PackagesTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Homebrew outdated").font(.headline)
                Spacer()
                Button("Refresh") { model.packages.refresh() }
            }
            if model.packages.busy { ProgressView() }
            if model.packages.brewOutdated.isEmpty {
                Text("Apps with updates waiting — App Store, Homebrew and direct downloads").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(model.packages.brewOutdated, id: \.self) { Text($0) }
        }
        .onAppear { if model.packages.brewOutdated.isEmpty { model.packages.refresh() } }
    }
}

struct ShortcutsTab: View {
    @State private var names: [String] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shortcuts").font(.headline)
            if names.isEmpty {
                Text("Build one in the Shortcuts app and it shows up here").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(names, id: \.self) { name in
                Button(name) {
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                    task.arguments = ["run", name]
                    try? task.run()
                }
            }
        }
        .onAppear {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            task.arguments = ["list"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            try? task.run()
            task.waitUntilExit()
            let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            names = text.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        }
    }
}

struct CalculatorTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Type a sum", text: $model.calculator.input)
                .font(.title3.monospacedDigit())
                .onSubmit { model.calculator.commit() }
            Text(model.calculator.result).font(.title.bold())
            ForEach(model.calculator.history.prefix(6), id: \.self) { Text($0).font(.caption) }
        }
    }
}

struct QuickSearchTab: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    @State private var engine = "Google"
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Engine", selection: $engine) {
                ForEach(model.prefs.searchEngines, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            TextField("Type a query, hit return", text: $query)
                .onSubmit { search() }
            Text("⌘1–9 switches engine mid-query. Type !yt or !gh as a one-off.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func search() {
        var q = query
        var template: String
        switch engine {
        case "YouTube": template = "https://www.youtube.com/results?search_query=%@"
        case "GitHub": template = "https://github.com/search?q=%@"
        case "DuckDuckGo": template = "https://duckduckgo.com/?q=%@"
        default: template = "https://www.google.com/search?q=%@"
        }
        if q.hasPrefix("!yt ") { template = "https://www.youtube.com/results?search_query=%@"; q.removeFirst(4) }
        if q.hasPrefix("!gh ") { template = "https://github.com/search?q=%@"; q.removeFirst(4) }
        let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        if let url = URL(string: String(format: template, encoded)) {
            NSWorkspace.shared.open(url)
        }
    }
}

struct NotificationsTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        if model.inbox.items.isEmpty {
            EmptyHint(title: "Notifications", detail: "Banners from Outlook, Teams, Slack and any other app collect here when they arrive as islands.")
        } else {
            ScrollView {
                ForEach(model.inbox.items) { item in
                    VStack(alignment: .leading) {
                        Text(item.app).font(.caption2).foregroundStyle(.secondary)
                        Text(item.title).font(.subheadline.weight(.semibold))
                        Text(item.body).font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                }
            }
        }
    }
}

struct TodoTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View { RemindersTab() }
}

struct CuelyTab: View {
    @EnvironmentObject var model: AppModel
    @State private var script = "Welcome to Cuely — a teleprompter in the notch.\n\nScroll a script while you present. Esc stops."
    @State private var offset: CGFloat = 0
    @State private var running = false
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(running ? "Stop" : "Begin Cuely session") { running.toggle() }
                Button("Follow voice") { model.dictation.toggle() }
            }
            ScrollView {
                Text(script)
                    .font(.system(size: model.prefs.cuelyFontSize))
                    .opacity(model.prefs.cuelyOpacity)
                    .offset(y: -offset)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            .clipped()
        }
        .onReceive(timer) { _ in
            if running, model.prefs.cuelyAutoScroll { offset += 0.45 * model.prefs.cuelyScrollSpeed }
        }
        .onChange(of: model.dictation.transcript) { _, text in
            if model.prefs.cuelyFollowVoice, !text.isEmpty { offset += 8 }
        }
    }
}

struct EmojiTab: View {
    private let emoji = "😀😁😂🤣😃😄😅😉😊😍😘😗😜🤔😎🤩🥳😭😡👍👎❤️🔥✨🎉🐶🐱🍀".map { String($0) }
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 10), spacing: 8) {
            ForEach(emoji, id: \.self) { item in
                Button(item) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item, forType: .string)
                }
                .font(.title2)
                .buttonStyle(.plain)
            }
        }
    }
}

struct MirrorTab: View {
    @StateObject private var camera = CameraPreview()
    var body: some View {
        VStack {
            CameraView(session: camera.session)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text("A quick camera glance without opening FaceTime.").font(.caption).foregroundStyle(.secondary)
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }
}

final class CameraPreview: NSObject, ObservableObject {
    let session = AVCaptureSession()
    func start() {
        AVCaptureDevice.requestAccess(for: .video) { ok in
            guard ok, let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }
            self.session.beginConfiguration()
            if self.session.inputs.isEmpty { self.session.addInput(input) }
            self.session.commitConfiguration()
            DispatchQueue.global().async { self.session.startRunning() }
        }
    }

    func stop() { session.stopRunning() }
}

struct CameraView: NSViewRepresentable {
    let session: AVCaptureSession
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = CGRect(x: 0, y: 0, width: 600, height: 220)
        view.wantsLayer = true
        view.layer = preview
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView.layer as? AVCaptureVideoPreviewLayer)?.session = session
    }
}

struct StocksTab: View {
    @EnvironmentObject var model: AppModel
    @State private var symbol = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Add symbol", text: $symbol)
                    .onSubmit {
                        model.stocks.symbols.append(symbol.uppercased())
                        symbol = ""
                        model.stocks.refresh()
                    }
                Button("Refresh") { model.stocks.refresh() }
            }
            ForEach(model.stocks.quotes) { quote in
                HStack {
                    Text(quote.id).font(.headline)
                    Spacer()
                    Text(quote.price)
                    Text(quote.change).foregroundStyle(quote.change.contains("-") ? .red : .green)
                }
            }
        }
        .onAppear { model.stocks.refresh() }
    }
}

struct HomeKitTab: View {
    var body: some View {
        EmptyHint(title: "Home controls", detail: "Control your HomeKit lights and scenes without leaving the notch. Grant Home access in System Settings, then scenes appear here. Home controls run through Shortcuts if HomeKit is unavailable.")
    }
}

struct TerminalTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("zsh command", text: $model.terminal.command)
                .font(.system(.body, design: .monospaced))
                .onSubmit { model.terminal.run() }
            ScrollView {
                Text(model.terminal.output)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct SoundMixerTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(model.mixer.visualizer.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.mint)
                        .frame(width: 10, height: 20 + value * 80)
                }
            }
            .frame(height: 110, alignment: .bottom)
            Slider(value: Binding(
                get: { Double(model.mixer.systemVolume) },
                set: { model.mixer.setVolume(Int($0)) }
            ), in: 0 ... 100)
            Text("System volume \(model.mixer.systemVolume)%").font(.caption)
            HStack {
                labeled("Bass", $model.mixer.eqBass)
                labeled("Mid", $model.mixer.eqMid)
                labeled("Treble", $model.mixer.eqTreble)
            }
        }
    }

    private func labeled(_ title: String, _ value: Binding<Double>) -> some View {
        VStack {
            Text(title).font(.caption2)
            Slider(value: value, in: -12 ... 12)
        }
    }
}

struct QuickSettingsTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            toggle("Caffeine", model.caffeine.isActive) { model.caffeine.toggle() }
            toggle("Low Power", model.battery.isLowPowerMode) { }
            toggle("Pet", model.petOpen) { model.petOpen.toggle() }
            toggle("Hide notch", model.hideNotchBezel) { model.hideNotchBezel.toggle() }
            toggle("Typing sounds", model.typing.enabled) { model.prefs.typingSounds.toggle(); model.typing.enabled = model.prefs.typingSounds }
            Button("Lock Screen") { model.lockScreen() }
                .buttonStyle(.bordered)
            Button("Screenshot") { model.tools.screenshot(); model.showIsland(title: "Screenshot", message: "Select an area", symbol: "camera.viewfinder") }
                .buttonStyle(.bordered)
            Button("Color Picker") { model.tools.pickColor() }
                .buttonStyle(.bordered)
            Button("Scan QR") { model.tools.scanQR() }
                .buttonStyle(.bordered)
            Button("Settings…") { model.settingsOpen = true }
                .buttonStyle(.bordered)
        }
    }

    private func toggle(_ title: String, _ on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 12).fill(on ? Color.mint.opacity(0.25) : Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }
}
