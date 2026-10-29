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
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(shelf.items) { item in
                                    ShelfTile(item: item, thumbnail: shelf.thumbnails[item.id])
                                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(maxHeight: .infinity)
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
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fit)
                } else {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path)).resizable().aspectRatio(contentMode: .fit)
                }
            }
            .frame(width: 54, height: 54)
            Text(item.name)
                .font(.system(size: 10.5))
                .foregroundStyle(Island.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 78)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(hovering ? Color.white.opacity(0.1) : .clear))
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button { model.shelf.remove(item) } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundStyle(Island.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(item.name)")
            }
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
                        ForEach(clipboard.filtered) { item in
                            ClipRow(item: item, copied: copiedID == item.id, onCopy: { copy(item) }, clipboard: clipboard)
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
        withAnimation(.easeOut(duration: 0.15)) { copiedID = item.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedID == item.id { withAnimation { copiedID = nil } }
        }
    }
}

private struct ClipRow: View {
    let item: ClipItem
    let copied: Bool
    let onCopy: () -> Void
    @ObservedObject var clipboard: ClipboardService
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(Island.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines)).font(.system(size: 12)).foregroundStyle(Island.primary).lineLimit(1)
                Text([item.sourceApp, item.copiedAt.formatted(.relative(presentation: .named))].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 10.5)).foregroundStyle(Island.tertiary).lineLimit(1)
            }
            Spacer(minLength: 6)
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
        .help("Click to copy")
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
    @ObservedObject var calendar: CalendarService
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
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

            if model.prefs.showRemindersInTodo {
                remindersColumn.frame(width: 200)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: todo.items)
        .onAppear { if model.wantsKeyboard { fieldFocused = true } }
        .onChange(of: model.focusRequest) { _, _ in fieldFocused = true }
    }

    private var remindersColumn: some View {
        IslandCard(padding: 10) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Reminders Due Today")
                switch calendar.reminderAccess {
                case .granted:
                    if calendar.reminders.isEmpty {
                        Text("Nothing due").font(.system(size: 11.5)).foregroundStyle(Island.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(calendar.reminders) { reminder in
                                    HStack(spacing: 8) {
                                        Button { calendar.complete(reminder) } label: {
                                            Image(systemName: "circle").font(.system(size: 14)).foregroundStyle(Island.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Complete \(reminder.title)")
                                        Text(reminder.title).font(.system(size: 12)).foregroundStyle(Island.primary).lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                case .unknown:
                    Spacer(minLength: 0)
                    Button("Show Reminders") { calendar.requestReminderAccess() }.buttonStyle(PillButtonStyle())
                    Spacer(minLength: 0)
                case .denied:
                    Spacer(minLength: 0)
                    Button("Open Privacy Settings") { calendar.openPrivacySettings(reminders: true) }.buttonStyle(PillButtonStyle())
                    Spacer(minLength: 0)
                }
            }
        }
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
                    .foregroundStyle(item.done ? Island.positive : Island.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.done ? "Mark \(item.title) as not done" : "Complete \(item.title)")
            Text(item.title)
                .font(.system(size: 12))
                .strikethrough(item.done, color: Island.tertiary)
                .foregroundStyle(item.done ? Island.tertiary : Island.primary)
                .lineLimit(1)
            Spacer(minLength: 4)
            if deletable, hovering {
                IslandIconButton(symbol: "trash", label: "Delete", size: 22) { todo.delete(item) }
            }
        }
        .padding(.horizontal, deletable ? 10 : 0)
        .frame(height: deletable ? 30 : 22)
        .background {
            if deletable { RoundedRectangle(cornerRadius: 8, style: .continuous).fill(hovering ? Island.cardHover : Island.card) }
        }
        .onHover { hovering = $0 }
    }
}

// MARK: Pomodoro

struct TimerPanel: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var timer: FocusTimer

    var body: some View {
        HStack(spacing: 18) {
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
                } else if timer.mode == .countdown, !timer.isActive {
                    HStack(spacing: 6) {
                        ForEach([5, 10, 15, 25, 45], id: \.self) { minutes in
                            Button("\(minutes)m") { timer.setCountdown(minutes: Double(minutes)) }
                                .buttonStyle(ChipStyle(selected: Int(timer.total / 60) == minutes))
                        }
                    }
                }

                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Button(timer.isRunning ? "Pause" : (timer.isActive ? "Resume" : "Start")) { timer.toggle() }
                        .buttonStyle(PillButtonStyle(tint: tint))
                        .keyboardShortcut(.space, modifiers: [])
                    IslandIconButton(symbol: "arrow.counterclockwise", label: "Reset") { timer.reset() }
                    if timer.mode != .stopwatch {
                        IslandIconButton(symbol: "plus", label: "Add One Minute") { timer.addMinute() }
                    }
                    if timer.mode == .pomodoro {
                        IslandIconButton(symbol: "forward.end.fill", label: "Skip to Next Phase") { timer.skipPhase() }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private var tint: Color {
        timer.mode == .pomodoro && timer.phase != .focus ? Island.positive : Island.focus
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Island.numerals(11, weight: .semibold))
            .foregroundStyle(selected ? Color.black : Island.primary)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(Capsule().fill(selected ? Island.primary : Color.white.opacity(configuration.isPressed ? 0.2 : 0.1)))
    }
}

// MARK: Calendar

struct CalendarPanel: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var calendar: CalendarService

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Date.now.formatted(.dateTime.weekday(.wide))).font(.system(size: 12, weight: .semibold)).foregroundStyle(Island.focus)
                Text(Date.now.formatted(.dateTime.day())).font(Island.numerals(42, weight: .bold)).foregroundStyle(Island.primary)
                Text(Date.now.formatted(.dateTime.month(.wide))).font(.system(size: 12)).foregroundStyle(Island.secondary)
                Spacer(minLength: 0)
                Button("Open Calendar") { calendar.openCalendarApp() }
                    .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(Island.secondary)
            }
            .frame(width: 100, alignment: .leading)

            IslandCard(padding: 10) {
                CalendarAccessGate(calendar: calendar) {
                    let events = calendar.today.filter { model.prefs.showAllDayEvents || !$0.isAllDay }
                    let later = calendar.upcoming.filter { !Calendar.current.isDateInToday($0.start) }.prefix(3)
                    if events.isEmpty, later.isEmpty {
                        EmptyState(symbol: "calendar", title: "A Clear Day", message: "No events today.")
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(events) { EventRow(event: $0, calendar: calendar, compact: false) }
                                if !later.isEmpty {
                                    SectionLabel(text: "Tomorrow").padding(.top, 4)
                                    ForEach(Array(later)) { EventRow(event: $0, calendar: calendar, compact: false) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
