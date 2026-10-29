import AVFoundation
import SwiftUI

struct NotesPanel: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var notes: NotesService
    @FocusState private var focused: Bool

    var body: some View {
        TextEditor(text: $notes.text)
            .font(.system(size: 13))
            .foregroundStyle(Island.primary)
            .scrollContentBackground(.hidden)
            .focused($focused)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Island.card))
            .overlay(alignment: .topLeading) {
                if notes.text.isEmpty {
                    Text("Jot something down. It saves as you type.")
                        .font(.system(size: 13)).foregroundStyle(Island.tertiary)
                        .padding(.horizontal, 13).padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
            .onAppear { if model.wantsKeyboard { focused = true } }
            .onChange(of: model.focusRequest) { _, _ in focused = true }
    }
}

struct CalculatorPanel: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var calculator: CalculatorService
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            IslandCard(padding: 14) {
                VStack(alignment: .trailing, spacing: 6) {
                    TextField("12 × 4 + 7", text: $calculator.input)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .font(Island.numerals(18, weight: .medium))
                        .foregroundStyle(Island.secondary)
                        .focused($focused)
                        .onSubmit { calculator.commit() }
                    Spacer(minLength: 0)
                    Text(calculator.result ?? (calculator.input.isEmpty ? "0" : "—"))
                        .font(Island.numerals(36, weight: .bold))
                        .foregroundStyle(Island.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                    Text("Return copies the result").font(.system(size: 10.5)).foregroundStyle(Island.tertiary)
                }
            }
            IslandCard(padding: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "History")
                    if calculator.history.isEmpty {
                        Text("Results you copy appear here.").font(.system(size: 11)).foregroundStyle(Island.secondary)
                    }
                    ForEach(calculator.history, id: \.self) { line in
                        Text(line).font(Island.numerals(11, weight: .medium)).foregroundStyle(Island.secondary).lineLimit(1)
                    }
                }
            }
            .frame(width: 200)
        }
        .onAppear { focused = true }
        .onChange(of: model.focusRequest) { _, _ in focused = true }
    }
}

struct SearchPanel: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    @AppStorage("mochy.search.engine") private var engine = "Google"
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SearchField(prompt: "Search \(engine)", text: $query, focused: $focused) {
                guard !query.isEmpty else { return }
                SystemActions.search(query, engine: engine)
                query = ""
                model.collapse()
            }
            SegmentedChips(options: ["Google", "DuckDuckGo", "YouTube", "GitHub"].map { ($0, $0) }, selection: $engine)
            Spacer(minLength: 0)
        }
        .onAppear { focused = true }
        .onChange(of: model.focusRequest) { _, _ in focused = true }
    }
}

struct LauncherPanel: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var launcher: LauncherService
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 8) {
            SearchField(prompt: "Open an App", text: $launcher.query, focused: $focused) {
                if let first = launcher.results.first { open(first) }
            }
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 6)], spacing: 6) {
                    ForEach(launcher.results) { app in
                        Button { open(app) } label: {
                            VStack(spacing: 3) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: app.id.path)).resizable().frame(width: 36, height: 36)
                                Text(app.name).font(.system(size: 10.5)).foregroundStyle(Island.secondary).lineLimit(1)
                            }
                            .frame(width: 68, height: 58)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(app.name)
                    }
                }
            }
        }
        .onAppear {
            launcher.load()
            focused = true
        }
        .onChange(of: model.focusRequest) { _, _ in focused = true }
    }

    private func open(_ app: LauncherService.App) {
        launcher.open(app)
        launcher.query = ""
        model.collapse()
    }
}

struct EmojiPanel: View {
    @State private var copied: String?
    private static let emoji = Array("😀😂🥹😊😍🥰😘😎🤩🥳😴🤔🫡🙃😅😭😤🤯🥶🫠👍👎👏🙌🙏💪👀🫶❤️🧡💛💚💙💜🖤🤍🔥✨⭐️🌈☀️🌙⚡️🎉🎂🎁🍕🍔🍟☕️🍺🍷⚽️🏀🎮🎧🎵📷💻📱⌚️💡📌✅❌⚠️❓💯🚀✈️🏠🐶🐱🦊🐼🌸🍀").map(String.init)

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 34), spacing: 4)], spacing: 4) {
                ForEach(Self.emoji, id: \.self) { item in
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item, forType: .string)
                        withAnimation(.easeOut(duration: 0.15)) { copied = item }
                    } label: {
                        Text(item).font(.system(size: 22))
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(copied == item ? Color.white.opacity(0.2) : .clear))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let copied {
                Text("Copied \(copied)").font(.system(size: 11, weight: .semibold)).foregroundStyle(.black)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Island.primary))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: copied) {
                        try? await Task.sleep(for: .seconds(1.2))
                        withAnimation { self.copied = nil }
                    }
            }
        }
    }
}

struct MirrorPanel: View {
    @State private var status = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        Group {
            switch status {
            case .authorized:
                CameraPreview()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .scaleEffect(x: -1, y: 1)
            case .notDetermined:
                VStack(spacing: 8) {
                    EmptyState(symbol: "web.camera", title: "Mirror", message: "Check how you look before a call.")
                    Button("Turn On Camera") {
                        AVCaptureDevice.requestAccess(for: .video) { _ in
                            DispatchQueue.main.async { status = AVCaptureDevice.authorizationStatus(for: .video) }
                        }
                    }
                    .buttonStyle(PillButtonStyle())
                }
            default:
                VStack(spacing: 8) {
                    EmptyState(symbol: "web.camera", title: "Camera Access Is Off", message: "Allow Mochy in Privacy & Security › Camera.")
                    Button("Open Privacy Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") { NSWorkspace.shared.open(url) }
                    }
                    .buttonStyle(PillButtonStyle())
                }
            }
        }
    }
}

/// The capture session only runs while the Mirror tab is on screen.
private struct CameraPreview: NSViewRepresentable {
    final class PreviewView: NSView {
        let session = AVCaptureSession()
        private let queue = DispatchQueue(label: "mochy.mirror")

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            layer = preview
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        func start() {
            queue.async { [session] in
                if session.inputs.isEmpty, let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
                    session.addInput(input)
                }
                if !session.isRunning { session.startRunning() }
            }
        }

        func stop() {
            queue.async { [session] in if session.isRunning { session.stopRunning() } }
        }
    }

    func makeNSView(context _: Context) -> PreviewView {
        let view = PreviewView(frame: .zero)
        view.start()
        return view
    }

    func updateNSView(_: PreviewView, context _: Context) {}

    static func dismantleNSView(_ view: PreviewView, coordinator _: ()) {
        view.stop()
    }
}
