import SwiftUI

struct HomeTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: max(1, min(3, model.prefs.homeColumns))), spacing: 10) {
            ForEach(model.homeCards.filter(\.enabled)) { card in
                cardView(card)
            }
        }
    }

    @ViewBuilder
    private func cardView(_ card: HomeCard) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(card.title, systemImage: card.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            switch card.id {
            case "nowPlaying":
                Text(model.nowPlaying.title).font(.headline).lineLimit(1)
                Text(model.nowPlaying.artist).font(.caption).foregroundStyle(.secondary)
            case "weather":
                Text(model.weather.temperature).font(.title2.bold())
                Text(model.weather.condition + "  " + model.weather.forecast).font(.caption)
            case "battery":
                Text("\(model.battery.percent)%").font(.title2.bold())
                Text(model.battery.timeRemaining).font(.caption)
            case "calendar":
                if let next = model.calendar.nextEvent {
                    Text(next.title).font(.headline).lineLimit(1)
                    Text(next.start.formatted(date: .omitted, time: .shortened)).font(.caption)
                } else {
                    Text("No upcoming events").font(.caption)
                }
            case "pet":
                HStack {
                    MochiAvatar(pose: model.pet.pose).frame(width: 42, height: 42)
                    Text(model.pet.statusLine).font(.caption)
                }
            case "timer":
                Text(format(model.timer.remaining)).font(.title2.monospacedDigit())
                Text(model.timer.mode.rawValue.capitalized).font(.caption)
            case "focus":
                Text(model.focus.sessionActive ? "Focus on" : "Focus off").font(.headline)
            case "stocks":
                if let quote = model.stocks.quotes.first {
                    Text("\(quote.id) \(quote.price)").font(.headline)
                    Text(quote.change).font(.caption)
                } else {
                    Text("Add symbols in Stocks").font(.caption)
                }
            case "clipboard":
                Text(model.clipboard.items.first?.text ?? "Clipboard empty").font(.caption).lineLimit(3)
            case "shortcuts":
                Text("Run a shortcut from the Shortcuts tab").font(.caption)
            default:
                Text(card.title)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
    }
}

struct NowPlayingTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 72, height: 72)
                    .overlay(Image(systemName: "music.note").font(.title))
                VStack(alignment: .leading) {
                    Text(model.nowPlaying.title).font(.headline).lineLimit(1)
                    Text(model.nowPlaying.artist).foregroundStyle(.secondary)
                    Text(model.nowPlaying.appName).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.songID.listening ? "Listening" : "Song ID") { model.songID.toggle() }
                    .buttonStyle(.bordered)
            }
            ProgressView(value: model.nowPlaying.duration == 0 ? 0 : model.nowPlaying.position / max(model.nowPlaying.duration, 1))
            HStack {
                Button { model.nowPlaying.previous() } label: { Image(systemName: "backward.fill") }
                Button { model.nowPlaying.playPause() } label: {
                    Image(systemName: model.nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                }
                Button { model.nowPlaying.next() } label: { Image(systemName: "forward.fill") }
                Spacer()
                Slider(value: Binding(
                    get: { Double(model.mixer.systemVolume) },
                    set: { model.mixer.setVolume(Int($0)) }
                ), in: 0 ... 100)
                .frame(width: 140)
            }
            .buttonStyle(.plain)
            .font(.title3)
            if !model.songID.result.isEmpty {
                Text(model.songID.result).font(.caption).foregroundStyle(.secondary)
            }
            if model.prefs.lyricsInNowPlaying {
                Text(model.nowPlaying.lyrics.isEmpty ? "Lyrics appear here when a player publishes them." : model.nowPlaying.lyrics)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(6)
            }
        }
    }
}

struct CalendarTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.calendar.status).font(.caption).foregroundStyle(.secondary)
            if model.calendar.events.isEmpty {
                EmptyHint(title: "Calendar", detail: "Agenda and next event, with a Join button for video calls.")
            } else {
                ScrollView {
                    ForEach(model.calendar.events) { event in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(event.title).font(.subheadline.weight(.semibold))
                                Text("\(event.start.formatted(date: .abbreviated, time: .shortened)) · \(event.calendarName)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let url = event.joinURL {
                                Button("Join") { NSWorkspace.shared.open(url) }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

struct RemindersTab: View {
    @EnvironmentObject var model: AppModel
    @State private var draft = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Add a reminder…", text: $draft)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                    .onSubmit {
                        model.calendar.addReminder(draft)
                        draft = ""
                    }
            }
            ScrollView {
                ForEach(model.calendar.reminders, id: \.calendarItemIdentifier) { reminder in
                    Button {
                        model.calendar.toggle(reminder)
                    } label: {
                        HStack {
                            Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                            Text(reminder.title)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct NotesTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scratchpad").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $model.notes.draft)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                .onChange(of: model.notes.draft) { _, _ in model.notes.save() }
            HStack {
                Button("Save to Apple Notes") { model.notes.sendToAppleNotes() }
                Spacer()
                Button("Dictation") { model.dictation.toggle() }
            }
            if !model.dictation.transcript.isEmpty {
                Text(model.dictation.transcript).font(.caption)
            }
        }
    }
}

struct TimerTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(spacing: 12) {
            Picker("Mode", selection: $model.timer.mode) {
                ForEach(TimerService.Mode.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(model.timer.mode == .stopwatch ? format(model.timer.elapsed) : format(model.timer.remaining))
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if model.timer.mode == .pomodoro {
                Text(model.timer.pomodoroPhase).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button(model.timer.running ? "Pause" : "Start") { model.timer.toggle() }
                Button("Reset") { model.timer.reset() }
                if model.timer.mode == .timer {
                    Button("5m") { model.timer.setMinutes(5) }
                    Button("15m") { model.timer.setMinutes(15) }
                    Button("25m") { model.timer.setMinutes(25) }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ClipboardTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        if model.clipboard.items.isEmpty {
            EmptyHint(title: "Clipboard history is empty", detail: "Copied text lands here. Items copy back, they never paste themselves.")
        } else {
            ScrollView {
                ForEach(model.clipboard.items) { item in
                    Button {
                        model.clipboard.copy(item.text)
                        model.showIsland(title: "Copied", message: String(item.text.prefix(40)), symbol: "doc.on.clipboard")
                    } label: {
                        Text(item.text).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                }
            }
        }
    }
}

struct FilesTab: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shelf").font(.headline)
            if model.shelf.files.isEmpty, model.folders.downloads.isEmpty {
                Text("Downloads show live progress in the notch and land on the Shelf").font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                ForEach(model.folders.downloads.prefix(12), id: \.self) { url in
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text(url.lastPathComponent).lineLimit(1)
                        Spacer()
                        Button("Show") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    }
                    .font(.caption)
                }
                ForEach(model.shelf.files, id: \.self) { url in
                    HStack {
                        Image(systemName: "internaldrive")
                        Text(url.lastPathComponent).lineLimit(1)
                        Spacer()
                    }
                    .font(.caption)
                }
            }
            HStack {
                Button("Capture Screenshot") { model.captureScreenshot() }
                Button("Open Downloads") {
                    if let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}

func format(_ interval: TimeInterval) -> String {
    let t = Int(interval)
    return String(format: "%02d:%02d", t / 60, t % 60)
}
