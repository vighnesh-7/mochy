import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Reads file URLs out of a drop. Calls back on the main actor with whatever loaded.
func loadFileURLs(_ providers: [NSItemProvider], completion: @escaping @MainActor ([URL]) -> Void) -> Bool {
    let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
    guard !fileProviders.isEmpty else { return false }
    let group = DispatchGroup()
    let lock = NSLock()
    var urls: [URL] = []
    for provider in fileProviders {
        group.enter()
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url, url.isFileURL {
                lock.lock()
                urls.append(url)
                lock.unlock()
            }
            group.leave()
        }
    }
    group.notify(queue: .main) {
        MainActor.assumeIsolated { completion(urls) }
    }
    return true
}

// MARK: Shelf

struct ShelfPanel: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var shelf: ShelfService
    @State private var targeted = false
    @State private var airDropTargeted = false

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if shelf.items.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(targeted ? Island.primary : Island.tertiary)
                        Text("Drop Files Here").font(.system(size: 13, weight: .semibold)).foregroundStyle(Island.primary)
                        Text("Drag them back out whenever you need them.").font(.system(size: 11.5)).foregroundStyle(Island.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                            .foregroundStyle(targeted ? Island.primary : Color.white.opacity(0.22))
                    )
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            SectionLabel(text: "\(shelf.items.count) \(shelf.items.count == 1 ? "File" : "Files")")
                            Spacer()
                            Button("Clear") { withAnimation { shelf.clear() } }
                                .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(Island.secondary)
                        }
                        GeometryReader { geo in
                            let thumb = min(128, max(88, geo.size.height - 34))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 28) {
                                    ForEach(shelf.items) { item in
                                        ShelfTile(item: item, thumbnail: shelf.thumbnails[item.id], thumbSize: thumb)
                                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(targeted ? Island.cardHover : Island.card))
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
                loadFileURLs(providers) { model.addToShelf($0) }
            }

            airDropTile
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: shelf.items)
        .animation(.easeOut(duration: 0.15), value: targeted)
    }

    private var airDropTile: some View {
        Button {
            model.airDrop(shelf.items.map(\.url))
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "airplayaudio")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(airDropTargeted ? Color.black : Island.info)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(airDropTargeted ? Island.info : Island.info.opacity(0.18)))
                Text("AirDrop").font(.system(size: 12, weight: .semibold)).foregroundStyle(Island.primary)
                Text(shelf.items.isEmpty ? "Drop a file" : "Send all").font(.system(size: 10.5)).foregroundStyle(Island.secondary)
            }
            .frame(width: 104)
            .frame(maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(airDropTargeted ? Island.cardHover : Island.card))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(shelf.items.isEmpty && !airDropTargeted)
        .help("Drop files here to AirDrop them")
        .accessibilityLabel("AirDrop")
        .onDrop(of: [.fileURL], isTargeted: $airDropTargeted) { providers in
            loadFileURLs(providers) { model.airDrop($0) }
        }
    }
}

private struct ShelfTile: View {
    @EnvironmentObject var model: AppModel
    let item: ShelfItem
    let thumbnail: NSImage?
    var thumbSize: CGFloat = 112
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path)).resizable().aspectRatio(contentMode: .fit)
                }
            }
            .frame(width: thumbSize, height: thumbSize)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(item.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Island.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: thumbSize)
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(hovering ? Color.white.opacity(0.1) : .clear))
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button { model.shelf.remove(item) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, Color.black.opacity(0.72))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(4)
                .accessibilityLabel("Remove \(item.name)")
            }
        }
        .zIndex(hovering ? 1 : 0)
        .overlay(alignment: .bottomTrailing) {
            Menu {
                Button("Quick Look", systemImage: "eye") { FileTools.quickLook(item.url) }
                Divider()
                Menu("Convert to") {
                    Button("JPEG") { convert(.jpeg) }
                    Button("JPG") { convert(.jpg) }
                    Button("PNG") { convert(.png) }
                    Button("WebP") { convert(.webp) }
                    Button("HEIC", systemImage: "photo") { convert(.heic) }
                    Button("TIFF", systemImage: "photo") { convert(.tiff) }
                    Button("PDF", systemImage: "doc.richtext") { convert(.pdf) }
                }
                Menu("Compress to") {
                    Button("Custom…", systemImage: "slider.horizontal.3") { convert(.jpeg, quality: 0.55) }
                }
                Menu("Resize to") {
                    Button("640 px", systemImage: "arrow.down.right.and.arrow.up.left") { resize(640) }
                    Button("1024 px", systemImage: "arrow.down.right.and.arrow.up.left") { resize(1024) }
                }
                Button("Zip", systemImage: "archivebox") { zip() }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 14))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Island.primary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 18, height: 18)
            .opacity(hovering ? 1 : 0.85)
            .help("More")
        }
        .onHover { hovering = $0 }
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .onTapGesture(count: 2) { model.shelf.open(item) }
        .contextMenu {
            Button("Open") { model.shelf.open(item) }
            Button("Show in Finder") { model.shelf.reveal(item) }
            Button("AirDrop") { model.airDrop([item.url]) }
            Divider()
            Button("Remove from Shelf") { model.shelf.remove(item) }
        }
        .help(item.name)
        .accessibilityLabel(item.name)
    }

    private func convert(_ format: FileTools.Format, quality: Double = 0.82) {
        do {
            let url = try FileTools.convert(item.url, to: format, quality: quality)
            model.shelf.add([url])
        } catch {
            model.shelf.report(error.localizedDescription)
        }
    }

    private func resize(_ longest: CGFloat) {
        do {
            let url = try FileTools.resize(item.url, longest: longest)
            model.shelf.add([url])
        } catch {
            model.shelf.report(error.localizedDescription)
        }
    }

    private func zip() {
        do {
            let url = try FileTools.zip([item.url])
            model.shelf.add([url])
        } catch {
            model.shelf.report(error.localizedDescription)
        }
    }
}

// MARK: Clipboard

struct ClipboardPanel: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var clipboard: ClipboardService
    @FocusState private var searchFocused: Bool
    @State private var copiedID: UUID?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                SearchField(prompt: "Search Clipboard", text: $clipboard.query, focused: $searchFocused) {
                    if let first = clipboard.filtered.first { copy(first) }
                }
                Button("Clear") { clipboard.clearHistory() }
                    .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(Island.secondary)
                    .disabled(clipboard.items.isEmpty)
            }
            if !model.prefs.clipboardHistory {
                EmptyState(symbol: "doc.on.clipboard", title: "Clipboard History Is Off", message: "Turn it on in Settings › Clipboard.")
            } else if clipboard.filtered.isEmpty {
                EmptyState(symbol: "doc.on.clipboard", title: clipboard.query.isEmpty ? "Nothing Copied Yet" : "No Matches", message: clipboard.query.isEmpty ? "Text, links and files you copy show up here." : "Try a different search.")
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(clipboard.filtered.enumerated()), id: \.element.id) { index, item in
                            ClipRow(item: item, slot: index < 9 ? index + 1 : nil, copied: copiedID == item.id, onCopy: { copy(item) }, clipboard: clipboard)
                        }
                    }
                }
            }
        }
        .onAppear { if model.wantsKeyboard { searchFocused = true } }
        .onChange(of: model.focusRequest) { _, _ in searchFocused = true }
    }

    private func copy(_ item: ClipItem) {
        clipboard.copy(item)
        model.playPopSound()
        withAnimation(.easeOut(duration: 0.15)) { copiedID = item.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedID == item.id { withAnimation { copiedID = nil } }
        }
    }
}

private struct ClipRow: View {
    let item: ClipItem
    var slot: Int?
    let copied: Bool
    let onCopy: () -> Void
    @ObservedObject var clipboard: ClipboardService
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(Island.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 12))
                    .foregroundStyle(item.openURL == nil ? Island.primary : Color.blue)
                    .lineLimit(1)
                Text([item.sourceApp, item.copiedAt.formatted(.relative(presentation: .named))].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 10.5)).foregroundStyle(Island.tertiary).lineLimit(1)
            }
            Spacer(minLength: 6)
            if let url = item.openURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Island.primary)
                        .frame(width: 22, height: 22)
                        .background(Capsule().fill(Color.white.opacity(0.16)))
                }
                .buttonStyle(.plain)
                .help("Open \(url.absoluteString)")
                .accessibilityLabel("Open Link")
            }
            if let slot {
                Text("\(slot)")
                    .font(Island.numerals(13, weight: .bold))
                    .foregroundStyle(Island.secondary)
                    .frame(width: 18, alignment: .trailing)
                    .accessibilityLabel("Snippet \(slot)")
            }
            if copied {
                Label("Copied", systemImage: "checkmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(Island.positive)
                    .transition(.opacity)
            } else if hovering || item.pinned {
                IslandIconButton(symbol: item.pinned ? "pin.fill" : "pin", label: item.pinned ? "Unpin" : "Pin", tint: item.pinned ? Island.focus : Island.secondary, size: 24) { clipboard.togglePin(item) }
                if hovering {
                    IslandIconButton(symbol: "trash", label: "Delete", size: 24) { clipboard.delete(item) }
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(hovering ? Island.cardHover : Island.card))
        .contentShape(Rectangle())
        .onTapGesture(perform: onCopy)
        .onHover { hovering = $0 }
        .help(slot.map { "Press \($0) to paste" } ?? "Click to copy")
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Copy", onCopy)
    }

    private var symbol: String {
        switch item.kind {
        case .text: "text.alignleft"
        case .link: "link"
        case .file: "doc"
        }
    }
}

struct SearchField: View {
    let prompt: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .semibold)).foregroundStyle(Island.tertiary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Island.primary)
                .focused(focused)
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Island.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear Search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Island.card))
    }
}

// MARK: To-Do

struct TodoPanel: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var todo: TodoStore
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.system(size: 14)).foregroundStyle(Island.focus)
                TextField("New To-Do", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Island.primary)
                    .focused($fieldFocused)
                    .onSubmit {
                        todo.add(draft)
                        draft = ""
                    }
                if todo.items.contains(where: \.done) {
                    Button("Clear Done") { withAnimation { todo.clearCompleted() } }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(Island.secondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Island.card))

            if todo.items.isEmpty {
                EmptyState(symbol: "checklist", title: "Nothing to Do", message: "Type above and press Return.")
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(todo.ordered) { TodoRow(item: $0, todo: todo, deletable: true) }
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: todo.items)
        .onAppear { if model.wantsKeyboard { fieldFocused = true } }
        .onChange(of: model.focusRequest) { _, _ in fieldFocused = true }
    }
}

struct TodoRow: View {
    let item: TodoItem
    @ObservedObject var todo: TodoStore
    var deletable = false
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { todo.toggle(item) } } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(item.done ? Color.green : Island.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.done ? "Mark \(item.title) as not done" : "Complete \(item.title)")
            VStack(alignment: .leading, spacing: 1) {
                TodoTitle(title: item.title, done: item.done, size: 12)
                if deletable {
                    Text(item.created.formatted(.relative(presentation: .named)))
                        .font(.system(size: 10.5))
                        .foregroundStyle(Island.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if deletable, hovering {
                IslandIconButton(symbol: "trash", label: "Delete", size: 22) { todo.delete(item) }
            }
        }
        .padding(.horizontal, deletable ? 10 : 0)
        .frame(height: deletable ? 40 : 22)
        .background {
            if deletable { RoundedRectangle(cornerRadius: 8, style: .continuous).fill(hovering ? Island.cardHover : Island.card) }
        }
        .onHover { hovering = $0 }
    }
}

struct TodoTitle: View {
    @EnvironmentObject var model: AppModel
    let title: String
    var done = false
    var size: CGFloat = 12

    var body: some View {
        let link = model.prefs.todoRecognizeURLs ? TodoStore.Link.httpsURL(in: title) : nil
        let shown = TodoStore.Link.display(title, trimPrefix: link != nil && model.prefs.todoTrimURLPrefix)
        let label = Text(shown)
            .font(.system(size: size))
            .strikethrough(done, color: Island.tertiary)
            .foregroundStyle(done ? Island.tertiary : (link == nil ? Island.primary : Color.blue))
            .lineLimit(2)
        if link != nil {
            Button {
                if let url = TodoStore.Link.opening(title, stripTrackers: model.prefs.todoStripTrackers) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                label
            }
            .buttonStyle(.plain)
            .onHover { inside in
                if inside { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
            }
            .help(title)
        } else {
            label
        }
    }
}

// MARK: Pomodoro

struct TimerPanel: View {
    @ObservedObject var timer: FocusTimer

    var body: some View {
        HStack(spacing: 18) {
            Button {
                timer.toggle()
            } label: {
                ZStack {
                    Ring(progress: timer.mode == .stopwatch ? 0 : timer.progress, tint: tint, lineWidth: 6)
                    VStack(spacing: 0) {
                        Text(timer.display).font(Island.numerals(26, weight: .bold)).foregroundStyle(Island.primary)
                            .contentTransition(.numericText(countsDown: timer.mode != .stopwatch))
                        Text(timer.mode == .pomodoro ? timer.phase.title : timer.mode.title)
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(tint)
                    }
                }
                .frame(width: 124, height: 124)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(timer.isRunning ? "Pause" : "Start")
            .accessibilityLabel(timer.isRunning ? "Pause \(timer.mode.title)" : "Start \(timer.mode.title)")
            .animation(.linear(duration: 0.25), value: timer.progress)

            VStack(alignment: .leading, spacing: 12) {
                SegmentedChips(options: FocusTimer.Mode.allCases.map { ($0, $0.title) }, selection: Binding(get: { timer.mode }, set: { timer.select($0) }))

                if timer.mode == .pomodoro {
                    HStack(spacing: 6) {
                        Text("Round").font(.system(size: 11)).foregroundStyle(Island.tertiary)
                        ForEach(1 ... max(timer.roundsBeforeLongBreak, 1), id: \.self) { index in
                            Circle().fill(index <= timer.round ? Island.focus : Color.white.opacity(0.18)).frame(width: 7, height: 7)
                        }
                    }
                } else if timer.mode == .countdown, !timer.isRunning {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            ForEach([5, 10, 15, 25], id: \.self) { minutes in
                                countdownChip(minutes)
                            }
                        }
                        HStack(spacing: 6) {
                            ForEach([30, 45, 60], id: \.self) { minutes in
                                countdownChip(minutes)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Button(timer.isRunning ? "Pause" : (timer.isActive ? "Resume" : "Start")) { timer.toggle() }
                        .buttonStyle(PillButtonStyle(tint: tint))
                        .keyboardShortcut(.space, modifiers: [])
                    IslandIconButton(symbol: "arrow.counterclockwise", label: "Reset") { timer.reset() }
                    if timer.mode != .stopwatch {
                        ForEach([15, 10, 5], id: \.self) { minutes in
                            Button("+\(minutes)") { timer.adjust(minutes: Double(minutes)) }
                                .buttonStyle(ChipStyle(fill: Color.green.opacity(0.32)))
                        }
                        ForEach([-5, -10, -15], id: \.self) { minutes in
                            Button("\(minutes)") { timer.adjust(minutes: Double(minutes)) }
                                .buttonStyle(ChipStyle(fill: Color.red.opacity(0.32)))
                        }
                    }
                    if timer.mode == .pomodoro {
                        IslandIconButton(symbol: "forward.end.fill", label: "Skip to Next Phase") { timer.skipPhase() }
                    }
                    PomodoroCount(count: timer.completedToday)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private var tint: Color {
        timer.mode == .pomodoro && timer.phase != .focus ? Island.positive : Island.focus
    }

    private func countdownChip(_ minutes: Int) -> some View {
        Button(minutes == 60 ? "1h" : "\(minutes)m") { timer.setCountdown(minutes: Double(minutes)) }
            .buttonStyle(ChipStyle(selected: Int(timer.total / 60) == minutes))
    }
}

struct SegmentedChips<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    @Namespace private var space

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { value, title in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selection = value }
                } label: {
                    Text(title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(selection == value ? Color.black : Island.secondary)
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .background {
                            if selection == value {
                                Capsule().fill(Island.primary).matchedGeometryEffect(id: "chip", in: space)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(Island.card))
    }
}

struct ChipStyle: ButtonStyle {
    var selected = false
    var fill: Color?
    func makeBody(configuration: Configuration) -> some View {
        let resting = fill ?? Color.white.opacity(0.1)
        let pressed = fill?.opacity(0.7) ?? Color.white.opacity(0.2)
        configuration.label
            .font(Island.numerals(11, weight: .semibold))
            .foregroundStyle(selected ? Color.black : Island.primary)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(Capsule().fill(selected ? Island.primary : (configuration.isPressed ? pressed : resting)))
    }
}

/// Today's finished 25-minute pomodoros. Not a button; the count clears after 2:00 AM IST.
private struct PomodoroCount: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(Island.numerals(12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: count > 9 ? 34 : 28, height: 28)
            .background(Circle().fill(Color.blue.opacity(0.72)))
            .allowsHitTesting(false)
            .accessibilityLabel("\(count) pomodoros finished today")
    }
}

// MARK: Calendar

struct CalendarPanel: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var calendar: CalendarService

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            MonthCalendar(calendar: calendar)
                .frame(width: 214)

            IslandCard(padding: 10) {
                CalendarAccessGate(calendar: calendar) {
                    let events = calendar.events(on: calendar.selectedDay).filter { model.prefs.showAllDayEvents || !$0.isAllDay }
                    let day = calendar.selectedDay
                    let heading = Calendar.current.isDateInToday(day)
                        ? "Today"
                        : day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: heading)
                        if events.isEmpty {
                            EmptyState(
                                symbol: "calendar",
                                title: heading,
                                message: Calendar.current.isDateInToday(day) ? "No events today." : "No events on this day."
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView(showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(events) { EventRow(event: $0, calendar: calendar, compact: false) }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(minWidth: 240)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .onAppear { calendar.focusToday() }
    }
}

/// Month grid in the style of the Calendar widget: every day of the month is visible, today is a red circle.
private struct MonthCalendar: View {
    @ObservedObject var calendar: CalendarService

    var body: some View {
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: calendar.displayedMonth)) ?? calendar.displayedMonth
        let weekday = cal.component(.weekday, from: monthStart)
        let leading = (weekday - cal.firstWeekday + 7) % 7
        let daysInMonth = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let todayDay = cal.isDate(Date(), equalTo: monthStart, toGranularity: .month) ? cal.component(.day, from: Date()) : -1
        let selectedDay = cal.isDate(calendar.selectedDay, equalTo: monthStart, toGranularity: .month) ? cal.component(.day, from: calendar.selectedDay) : -1
        let weeks = monthWeeks(leading: leading, days: daysInMonth)
        IslandCard(padding: 8, fillHeight: false) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Button { calendar.shiftMonth(-1) } label: {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain).foregroundStyle(Island.secondary)
                    .accessibilityLabel("Previous Month")
                    Text(monthStart.formatted(.dateTime.month(.wide)))
                        .font(.system(size: 14, weight: .semibold))
                    Text(monthStart.formatted(.dateTime.year()))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Island.secondary)
                    Spacer(minLength: 0)
                    Button { calendar.shiftMonth(1) } label: {
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain).foregroundStyle(Island.secondary)
                    .accessibilityLabel("Next Month")
                    Button { calendar.openCalendarApp() } label: {
                        Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain).foregroundStyle(Island.secondary)
                    .accessibilityLabel("Open Calendar")
                }
                HStack(spacing: 0) {
                    ForEach(Array(weekdaySymbols(cal).enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Island.tertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                VStack(spacing: 0) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        HStack(spacing: 0) {
                            ForEach(Array(week.enumerated()), id: \.element.id) { _, cell in
                                Group {
                                    if let day = cell.day {
                                        dayButton(day, todayDay: todayDay, selectedDay: selectedDay, rowHeight: 24)
                                    } else {
                                        Color.clear.frame(maxWidth: .infinity).frame(height: 24)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func dayButton(_ day: Int, todayDay: Int, selectedDay: Int, rowHeight: CGFloat) -> some View {
        let isToday = day == todayDay
        let isSelected = day == selectedDay
        let isPast = todayDay != -1 && day < todayDay
        return Button {
            calendar.select(day: day)
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    if isToday {
                        Circle().fill(Color(nsColor: .systemRed))
                    } else if isSelected {
                        Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 1.25)
                    }
                    Text("\(day)")
                        .font(.system(size: min(11, rowHeight * 0.42), weight: isToday ? .bold : .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isToday ? Color.white : Island.primary)
                }
                .frame(width: min(22, rowHeight - 6), height: min(22, rowHeight - 6))
                EventColorDot(colors: calendar.dayColors[day] ?? [])
                    .frame(width: 6, height: 6)
            }
            .opacity(isPast && !isToday ? 0.55 : 1)
            .frame(maxWidth: .infinity)
            .frame(height: rowHeight)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isToday ? "Today, \(day)" : "\(day)")
        .accessibilityAddTraits(isSelected || isToday ? .isSelected : [])
    }

    private struct DayCell: Identifiable {
        let id: String
        let day: Int?
    }

    private func monthWeeks(leading: Int, days: Int) -> [[DayCell]] {
        var cells: [DayCell] = (0..<leading).map { DayCell(id: "lead-\($0)", day: nil) }
        cells += (1...days).map { DayCell(id: "day-\($0)", day: $0) }
        while cells.count % 7 != 0 {
            cells.append(DayCell(id: "trail-\(cells.count)", day: nil))
        }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0 ..< $0 + 7]) }
    }

    private func weekdaySymbols(_ calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }
}

private struct EventColorDot: View {
    let colors: [Color]

    var body: some View {
        let slices = Array(colors.prefix(4))
        Group {
            if slices.isEmpty {
                Color.clear
            } else if slices.count == 1 {
                Circle().fill(slices[0])
            } else {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = min(size.width, size.height) / 2
                    let step = 360.0 / Double(slices.count)
                    for (index, color) in slices.enumerated() {
                        var path = Path()
                        path.move(to: center)
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(-90 + step * Double(index)),
                            endAngle: .degrees(-90 + step * Double(index + 1)),
                            clockwise: false
                        )
                        path.closeSubpath()
                        context.fill(path, with: .color(color))
                    }
                }
            }
        }
        .clipShape(Circle())
    }
}
