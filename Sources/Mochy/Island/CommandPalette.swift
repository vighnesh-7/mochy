import SwiftUI

struct CommandPalette: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Jump to any setting or tool", text: $query)
                    .textFieldStyle(.plain)
                    .focused($focused)
            }
            .padding(10)
            Divider().overlay(Color.white.opacity(0.1))
            ScrollView {
                ForEach(results, id: \.id) { item in
                    Button {
                        item.run()
                        model.paletteOpen = false
                    } label: {
                        HStack {
                            Image(systemName: item.symbol)
                            Text(item.title)
                            Spacer()
                            Text(item.subtitle).font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(width: 420, height: 260)
        .background(glass(width: 420, height: 260, corner: 18))
        .onAppear { focused = true }
    }

    private var results: [PaletteItem] {
        var items: [PaletteItem] = TabID.allCases.map { tab in
            PaletteItem(id: tab.rawValue, title: tab.title, subtitle: "Tab", symbol: tab.symbol) {
                model.enabledTabs.insert(tab)
                model.expand(tab: tab)
            }
        }
        items.append(contentsOf: SettingsPage.allCases.map { page in
            PaletteItem(id: "set-\(page.rawValue)", title: page.title, subtitle: "Settings", symbol: "gearshape") {
                model.settingsPage = page
                model.settingsOpen = true
            }
        })
        items.append(contentsOf: [
            PaletteItem(id: "settings", title: "Open Settings", subtitle: model.prefs.settingsShortcut.display, symbol: "gear") { model.settingsOpen = true },
            PaletteItem(id: "shot", title: "Capture Screenshot", subtitle: "Capture", symbol: "camera.viewfinder") { model.tools.screenshot() },
            PaletteItem(id: "scrollshot", title: "Scrolling Screenshot", subtitle: "Capture", symbol: "rectangle.dashed") { model.tools.scrollingScreenshot() },
            PaletteItem(id: "color", title: "Color Picker", subtitle: "Capture", symbol: "eyedropper") { model.tools.pickColor() },
            PaletteItem(id: "qr", title: "Scan QR", subtitle: "Capture", symbol: "qrcode") { model.tools.scanQR() },
            PaletteItem(id: "lock", title: "Lock Screen", subtitle: "Quick Settings", symbol: "lock.fill") { model.lockScreen() },
            PaletteItem(id: "caf", title: "Toggle Caffeine", subtitle: "Stay awake", symbol: "cup.and.saucer.fill") { model.caffeine.toggle() },
            PaletteItem(id: "hide", title: "Hide Mochy", subtitle: "General", symbol: "eye.slash") { model.hidden = true; model.collapse() },
            PaletteItem(id: "plain", title: "Paste as Plain Text", subtitle: "Clipboard", symbol: "doc.plaintext") { model.tools.pastePlain() },
            PaletteItem(id: "pomo", title: "Start Pomodoro", subtitle: "Timer", symbol: "timer") { model.performShortcut(ShortcutCatalog.all.first { $0.id == "pomodoro" }!) },
            PaletteItem(id: "reset", title: "Factory reset", subtitle: "About", symbol: "arrow.counterclockwise") { model.factoryReset() },
        ])
        if query.isEmpty { return Array(items.prefix(12)) }
        return items.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
}

struct PaletteItem {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let run: () -> Void
}
