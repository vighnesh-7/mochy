import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var page: SettingsPage = .general

    var body: some View {
        HSplitView {
            List(SettingsPage.allCases, selection: $page) { item in
                Label(item.title, systemImage: icon(item)).tag(item)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)
            ScrollView {
                pageBody.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 860, minHeight: 560)
        .onAppear { page = model.settingsPage }
        .onChange(of: page) { _, new in model.settingsPage = new }
        .onChange(of: model.settingsPage) { _, new in page = new }
        .onChange(of: model.prefs) { _, _ in model.prefs.save() }
    }

    @ViewBuilder
    private var pageBody: some View {
        switch page {
        case .general: GeneralPage()
        case .appearance: AppearancePage()
        case .behavior: BehaviorPage()
        case .displays: DisplaysPage()
        case .tabs: TabsPage()
        case .home: HomePageView()
        case .permissions: PermissionsPage()
        case .battery: BatteryPage()
        case .caffeine: CaffeinePage()
        case .calendar: CalendarPage()
        case .nowPlaying: NowPlayingPage()
        case .capture: CapturePage()
        case .clipboard: ClipboardPage()
        case .notifications: NotificationsPage()
        case .calls: CallsPage()
        case .faceUnlock: FaceUnlockPage()
        case .lockScreen: LockScreenPage()
        case .typing: TypingPage()
        case .pointer: PointerPage()
        case .cuely: CuelyPage()
        case .timer: TimerPage()
        case .activity: ActivityPage()
        case .aiUsage: AIUsagePage()
        case .pet: PetPage()
        case .connectivity: ConnectivityPage()
        case .terminal: TerminalPage()
        case .quickSearch: QuickSearchPage()
        case .stocks: StocksPage()
        case .spaces: SpacesPage()
        case .knock: KnockPage()
        case .widgets: WidgetsPage()
        case .developer: DeveloperPage()
        case .gallery: GalleryPage()
        case .about: AboutPage()
        }
    }

    private func icon(_ page: SettingsPage) -> String {
        switch page {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .behavior: "hand.draw"
        case .displays: "display.2"
        case .tabs: "rectangle.split.3x1"
        case .home: "house"
        case .permissions: "lock.shield"
        case .battery: "battery.100"
        case .caffeine: "cup.and.saucer"
        case .calendar: "calendar"
        case .nowPlaying: "music.note"
        case .capture: "camera.viewfinder"
        case .clipboard: "doc.on.clipboard"
        case .notifications: "bell"
        case .calls: "phone"
        case .faceUnlock: "faceid"
        case .lockScreen: "lock"
        case .typing: "keyboard"
        case .pointer: "cursorarrow.click"
        case .cuely: "text.alignleft"
        case .timer: "timer"
        case .activity: "circle.circle"
        case .aiUsage: "sparkles"
        case .pet: "pawprint"
        case .connectivity: "wifi"
        case .terminal: "terminal"
        case .quickSearch: "magnifyingglass"
        case .stocks: "chart.line.uptrend.xyaxis"
        case .spaces: "squares.below.rectangle"
        case .knock: "hand.tap"
        case .widgets: "rectangle.3.group"
        case .developer: "hammer"
        case .gallery: "square.grid.3x3"
        case .about: "info.circle"
        }
    }
}

private struct PageTitle: View {
    let title: String
    let blurb: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.largeTitle.bold())
            Text(blurb).foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }
}

struct GeneralPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageTitle(title: "General", blurb: "Launch behavior, menu bar, gestures and global keyboard shortcuts.")
            Toggle("Open at Login", isOn: $model.prefs.launchAtLogin)
                .onChange(of: model.prefs.launchAtLogin) { _, on in LaunchAtLogin.set(on) }
            Toggle("Show menu bar icon", isOn: $model.prefs.showMenuBarIcon)
            Toggle("Battery in Menu Bar", isOn: $model.prefs.batteryInMenuBar)
            Toggle("Next Meeting in Menu Bar", isOn: $model.prefs.nextMeetingInMenuBar)
            Toggle("Hide Menu Bar Icons", isOn: $model.prefs.hideMenuBarIcons)
            Toggle("Reveal Hidden Icons on Menu Bar Hover", isOn: $model.prefs.revealHiddenIconsOnHover)
            Toggle("Hide the pill when your menu bar items collide with it", isOn: $model.prefs.hideWhenColliding)
            Toggle("Hide Mochy + Cuely from Zoom/Meet/Teams/OBS", isOn: $model.prefs.hideFromZoomMeetTeamsOBS)
            Picker("Language", selection: $model.prefs.language) {
                Text("System").tag("system")
                Text("English").tag("en")
                Text("日本語").tag("ja")
                Text("Deutsch").tag("de")
                Text("Français").tag("fr")
                Text("Español").tag("es")
                Text("中文").tag("zh")
            }
            Toggle("24-hour clock", isOn: $model.prefs.clock24h)
            Toggle("Detect Language", isOn: $model.prefs.detectLanguage)
            Divider()
            Text("Opening").font(.headline)
            Toggle("Hover to Open", isOn: $model.prefs.hoverToOpen)
            Slider(value: $model.prefs.hoverDelay, in: 0 ... 0.8) { Text("Hover Delay") }
            Toggle("Expand on Hover", isOn: $model.prefs.expandOnHover)
            Toggle("Auto Collapse", isOn: $model.prefs.autoCollapse)
            Slider(value: $model.prefs.collapseDelay, in: 0.2 ... 2) { Text("Collapse Delay") }
            Picker("Default Tab", selection: $model.prefs.defaultTab) {
                ForEach(TabID.allCases) { Text($0.title).tag($0.rawValue) }
            }
            Divider()
            Text("Keyboard Shortcuts").font(.headline)
            ForEach(ShortcutCatalog.all) { action in
                ShortcutRow(action: action)
            }
            Toggle("Command Palette Button", isOn: $model.prefs.commandPaletteButton)
        }
    }
}

struct AppearancePage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageTitle(title: "Appearance", blurb: "The notch's shape, size, material, color and motion.")
            Picker("Glass Look", selection: $model.prefs.glassLook) {
                Text("Glass (Default)").tag("Glass")
                Text("Liquid Glass").tag("Liquid")
                Text("Monochrome Glass").tag("Mono")
                Text("Flat dark fill").tag("Flat")
                Text("None").tag("None")
            }
            Toggle("Use the real system glass material on the panel and its cards", isOn: $model.prefs.liquidGlass)
            Toggle("Adapt to Your Appearance", isOn: $model.prefs.adaptToAppearance)
            Toggle("White Accents", isOn: $model.prefs.whiteAccents)
            Toggle("Monochrome Glass", isOn: $model.prefs.monochromeGlass)
            Slider(value: $model.prefs.glassOpacity, in: 0 ... 1) { Text("Opacity") }
            Slider(value: $model.prefs.glassRimBrightness, in: 0 ... 1) { Text("Glass rim brightness") }
            Picker("Shape", selection: $model.prefs.notchShape) {
                Text("Notch").tag("Notch")
                Text("Pill").tag("Pill")
                Text("Split pill").tag("Split")
            }
            Slider(value: $model.prefs.closedPillWidth, in: 160 ... 420) { Text("Closed Pill Size") }
            Slider(value: $model.prefs.closedPillHeight, in: 24 ... 48) { Text("Idle Pill Size") }
            Slider(value: $model.prefs.panelWidth, in: 420 ... 900) { Text("Panel Width") }
            Slider(value: $model.prefs.panelHeight, in: 220 ... 560) { Text("Panel Height") }
            Slider(value: $model.prefs.fontSize, in: 11 ... 18) { Text("Font Size") }
            Slider(value: $model.prefs.panelFontSize, in: 11 ... 20) { Text("Panel Font") }
            Picker("HUD Style", selection: $model.prefs.hudStyle) {
                Text("Pill").tag("Pill")
                Text("Circular Island HUD").tag("Circular")
                Text("Standard HUD Size").tag("Standard")
            }
            Slider(value: $model.prefs.hudSize, in: 0.7 ... 1.6) { Text("HUD Size") }
            Slider(value: $model.prefs.hudWidth, in: 240 ... 520) { Text("HUD Width") }
            Toggle("Black Out Screen Corners", isOn: $model.prefs.blackOutCorners)
            Toggle("Black out the menu-bar strip so the camera notch disappears", isOn: $model.prefs.hideNotchBezel)
            Toggle("Fade the island's black into frosted glass at its lower edge", isOn: $model.prefs.fadeIslandToGlass)
            Toggle("Tint the battery level red → amber → green", isOn: $model.prefs.colorCodedBattery)
            Toggle("Tint volume, brightness and battery levels red → amber → green", isOn: $model.prefs.colorCodedVolume)
            Slider(value: $model.prefs.animationSpeed, in: 0.5 ... 2) { Text("Animation Speed") }
            Toggle("Match Your Reduce Motion Setting", isOn: $model.prefs.matchReduceMotion)
        }
    }
}

struct BehaviorPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageTitle(title: "Behavior", blurb: "Hover to open, auto-collapse, swipe gestures.")
            Toggle("Require Double-Click", isOn: $model.prefs.requireDoubleClick)
            Toggle("Peek on Hover", isOn: $model.prefs.peekOnHover)
            Toggle("Music Peek", isOn: $model.prefs.musicPeek)
            Toggle("Timer Peek", isOn: $model.prefs.timerPeek)
            Toggle("Swipe Gestures", isOn: $model.prefs.swipeGestures)
            Toggle("Swipe to Change Tabs", isOn: $model.prefs.swipeToChangeTabs)
            Toggle("Swipe to Change Track", isOn: $model.prefs.swipeToChangeTrack)
            Toggle("Swipe to Dismiss", isOn: $model.prefs.swipeToDismiss)
            Toggle("Swipe down on the closed notch to open the panel", isOn: $model.prefs.swipeToOpen)
            Toggle("Double-tap modifier gesture", isOn: $model.prefs.doubleTapModifier)
            Toggle("Invisible Until Hover", isOn: $model.prefs.invisibleUntilHover)
            Toggle("Show Unlock Animation", isOn: $model.prefs.showUnlockAnimation)
            Picker("Hover Response", selection: $model.prefs.hoverResponse) {
                Text("Snappy").tag("Snappy")
                Text("Soft").tag("Soft")
                Text("None").tag("None")
            }
            Slider(value: $model.prefs.hoverDamping, in: 0.4 ... 1) { Text("Hover Damping") }
        }
    }
}

struct DisplaysPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageTitle(title: "Displays", blurb: "Choose which connected displays show Mochy.")
            Toggle("Show on every display", isOn: $model.prefs.showOnAllDisplays)
            Toggle("Only on the Display With the Pointer", isOn: $model.prefs.onlyDisplayWithPointer)
            Toggle("Hide the pill on all screens while your display is mirrored", isOn: $model.prefs.hidePillWhileMirrored)
            Toggle("Brightness Overlay", isOn: $model.prefs.brightnessOverlay)
            Toggle("Replace System Volume & Brightness Overlay", isOn: $model.prefs.replaceSystemHUD)
            Toggle("Brightness Keys Control External Displays", isOn: $model.prefs.brightnessKeysControlExternal)
            Toggle("Extra Dim", isOn: $model.prefs.extraDim)
            Toggle("Extra Brightness", isOn: $model.prefs.extraBrightness)
            Toggle("Quiet Brightness During Focus", isOn: $model.prefs.quietBrightnessDuringFocus)
            Toggle("HUD on the keyboard-brightness keys", isOn: $model.prefs.hudOnKeyboardBacklight)
            Toggle("Hide Mochy’s volume and brightness HUDs while Focus is active", isOn: $model.prefs.hideVolumeHUDDuringFocus)
            ForEach(NSScreen.screens, id: \.localizedName) { screen in
                Text(screen.localizedName).font(.headline)
            }
        }
    }
}

struct TabsPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Tabs", blurb: "Discover what Mochy can do, enable tabs, and open each feature’s settings.")
            Toggle("Tab Labels", isOn: .constant(true))
            ForEach(TabID.allCases) { tab in
                Toggle(isOn: Binding(
                    get: { model.enabledTabs.contains(tab) },
                    set: { on in
                        if on { model.enabledTabs.insert(tab) } else if model.enabledTabs.count > 1 { model.enabledTabs.remove(tab) }
                        model.prefs.enabledTabs = model.enabledTabs.map(\.rawValue)
                    }
                )) {
                    VStack(alignment: .leading) {
                        Label(tab.title, systemImage: tab.symbol)
                        Text(tab.blurb).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct HomePageView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Home", blurb: "Arrange the notch's Home tab — pick the cards, the order and the columns.")
            Stepper("Card Columns: \(model.prefs.homeColumns)", value: $model.prefs.homeColumns, in: 1 ... 3)
            Toggle("Compact Layout", isOn: $model.prefs.compactHome)
            Toggle("Show local weather on the Home tab", isOn: $model.prefs.weatherOnHome)
            Picker("Units", selection: $model.prefs.weatherUnits) { Text("°C").tag("C"); Text("°F").tag("F") }
            ForEach($model.prefs.homeCards) { $card in
                Toggle(card.title, isOn: $card.enabled)
            }
            Text("Quick Actions").font(.headline)
            Text("Choose the buttons beside your tabs and in Home’s Quick Actions card.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct PermissionsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PageTitle(title: "Permissions", blurb: "Features ask for access the first time you use them — camera, calendar, microphone and the rest.")
            ForEach([
                "Accessibility", "Calendar", "Reminders", "Camera", "Microphone",
                "Speech Recognition", "Bluetooth", "Location", "Contacts",
                "Screen Recording", "Input Monitoring", "Full Disk Access", "Automation",
            ], id: \.self) { name in
                HStack {
                    Text(name)
                    Spacer()
                    Button("Open") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security")!)
                    }
                }
            }
        }
    }
}

struct BatteryPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Battery & Fans", blurb: "Battery health, low-battery and charging alerts, and the charge limit.")
            Text("\(model.battery.percent)% · \(model.battery.timeRemaining) · health \(model.battery.health)")
            Toggle("Charging Island", isOn: $model.prefs.chargingIsland)
            Toggle("Battery Alerts", isOn: $model.prefs.lowBatteryIsland)
            Toggle("Battery Drain Warnings", isOn: $model.prefs.batteryDrainWarnings)
            Toggle("Accessories Low Battery", isOn: $model.prefs.accessoryAlerts)
            Stepper("Accessory Alert Level: \(model.prefs.accessoryAlertLevel)%", value: $model.prefs.accessoryAlertLevel, in: 5 ... 20)
            Toggle("Accessory Fully Charged", isOn: $model.prefs.accessoryFullyChargedIsland)
            Toggle("Hide macOS Battery Alerts", isOn: $model.prefs.hideMacOSBatteryAlerts)
            Toggle("Notify on Low Power Mode", isOn: $model.prefs.notifyLowPowerMode)
            Toggle("Charge Limit", isOn: $model.prefs.chargeLimitEnabled)
            if model.prefs.chargeLimitEnabled {
                Slider(value: Binding(get: { Double(model.prefs.chargeLimitPercent) }, set: { model.prefs.chargeLimitPercent = Int($0) }), in: 50 ... 100) {
                    Text("Hold at \(model.prefs.chargeLimitPercent)%")
                }
                Text("Charge Limit needs a privileged helper. This build reports battery from IOKit and does not write SMC charge limits.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Toggle("Fan Control (Beta)", isOn: $model.prefs.fanControl)
            Text("Fan Control Needs Its Helper. This Mac’s firmware may not allow setting fan speeds.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct CaffeinePage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Caffeine", blurb: "Caffeine — keep this Mac awake.")
            Toggle("Keep Awake Button", isOn: $model.prefs.caffeineButton)
            Toggle("Caffeine Notifications", isOn: $model.prefs.caffeineNotifications)
            Toggle("Show the stopwatch next to Caffeine", isOn: $model.prefs.stopwatchNextToCaffeine)
            Button(model.caffeine.isActive ? "Deactivate Caffeine" : "Turn On Caffeine") { model.caffeine.toggle() }
            Text("Long-press Caffeine on the pill to pick a duration without opening Settings.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct CalendarPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Calendar", blurb: "A countdown island before your next event, with a Join button for video calls.")
            Text(model.calendar.status)
            Button("Allow Calendar Access") { model.calendar.request() }
            Toggle("Countdown island", isOn: $model.prefs.countdownIsland)
            Stepper("Alert \(model.prefs.countdownMinutes) min before", value: $model.prefs.countdownMinutes, in: 1 ... 30)
            Toggle("Join button", isOn: $model.prefs.joinButton)
            Toggle("Calendar Capture", isOn: $model.prefs.calendarCapture)
            Toggle("Natural-Language Reminder Dates", isOn: $model.prefs.naturalLanguageReminderDates)
            Toggle("Skip events without a Zoom, Meet, Teams or other video link", isOn: $model.prefs.skipEventsWithoutVideo)
            Toggle("Your next event, with a join button", isOn: $model.prefs.nextMeetingInPill)
        }
    }
}

struct NowPlayingPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Now Playing", blurb: "The music island, player and lyrics.")
            Toggle("Lyrics on the Pill", isOn: $model.prefs.lyricsOnPill)
            Toggle("Synced Lyrics", isOn: $model.prefs.syncedLyrics)
            Toggle("Lyrics in Now Playing", isOn: $model.prefs.lyricsInNowPlaying)
            Toggle("Desktop Lyrics", isOn: $model.prefs.desktopLyrics)
            Toggle("Full-Screen Lyrics", isOn: $model.prefs.fullScreenLyrics)
            Toggle("Always Show Track Info", isOn: $model.prefs.alwaysShowTrackInfo)
            Toggle("Announce New Tracks", isOn: $model.prefs.announceNewTracks)
            Toggle("Control Playback with Media Keys", isOn: $model.prefs.controlPlaybackWithMediaKeys)
            Toggle("Audio-Reactive Bars", isOn: $model.prefs.audioReactiveBars)
            Toggle("App Volume", isOn: $model.prefs.appVolumeMixer)
            Toggle("Equalizer", isOn: $model.prefs.equalizerEnabled)
            Toggle("Song change island", isOn: $model.prefs.songChangeIsland)
            TextField("Spotify Client ID", text: $model.prefs.spotifyClientID)
            Text("Add your Spotify Client ID in Settings first. Redirect URI: mochy://spotify")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct CapturePage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Capture", blurb: "Screenshot island and markup editor.")
            Toggle("Screenshot to Shelf", isOn: $model.prefs.screenshotToShelf)
            Toggle("Annotate After Capture", isOn: $model.prefs.annotateAfterCapture)
            Toggle("Add a Watermark", isOn: $model.prefs.watermark)
            if model.prefs.watermark {
                TextField("Watermark Text", text: $model.prefs.watermarkText)
                Slider(value: $model.prefs.watermarkOpacity, in: 0.1 ... 1) { Text("Watermark Opacity") }
            }
            Toggle("Scrolling Screenshot", isOn: $model.prefs.scrollingScreenshot)
            Toggle("Copy a screenshot and Mochy pulls the text out of it, on-device", isOn: $model.prefs.ocrScreenshots)
            Toggle("Keep the pill out of screenshots, recordings and shares", isOn: $model.prefs.keepPillOutOfCaptures)
            Toggle("Color Picker Button", isOn: $model.prefs.colorPickerButton)
            Toggle("Scan QR Codes", isOn: $model.prefs.qrButton)
            Toggle("Record Button", isOn: $model.prefs.recordButton)
            Toggle("Screenshot Island", isOn: $model.prefs.screenshotIsland)
            HStack {
                Button("Capture Screenshot") { model.tools.screenshot(); model.showIsland(title: "Screenshot", message: "Select an area", symbol: "camera.viewfinder") }
                Button("Scrolling Screenshot") { model.tools.scrollingScreenshot() }
                Button("Color Picker") { model.tools.pickColor() }
                Button("Scan QR") { model.tools.scanQR() }
                Button(model.tools.recording ? "Recording…" : "Record Screen") { model.tools.recordScreen() }
            }
            if !model.tools.lastQR.isEmpty { Text("QR: \(model.tools.lastQR)").font(.caption) }
            if !model.tools.lastColor.isEmpty { Text("Color: \(model.tools.lastColor)").font(.caption) }
        }
    }
}

struct ClipboardPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Clipboard", blurb: "Your clipboard history: a scrollable, pinnable copy shelf.")
            Toggle("Clipboard capture is on", isOn: $model.prefs.clipboardCapture)
            Toggle("Clipboard Capture Sound", isOn: $model.prefs.clipboardCaptureSound)
            Toggle("Two ⌘C Opens History", isOn: $model.prefs.twoCommandCOpensHistory)
            Toggle("Strip the trackers the moment a link is copied, with no click", isOn: $model.prefs.stripTrackers)
            Toggle("Auto-Clear", isOn: $model.prefs.autoClearClipboard)
            Slider(value: $model.prefs.autoClearSeconds, in: 15 ... 300) { Text("Idle time before the clipboard is emptied") }
            Stepper("History limit \(model.prefs.historyLimit)", value: $model.prefs.historyLimit, in: 10 ... 200)
            ShortcutRow(action: ShortcutCatalog.all.first { $0.id == "clipboard" }!)
            ShortcutRow(action: ShortcutCatalog.all.first { $0.id == "pastePlain" }!)
            Button("Clear Clipboard Now") { model.clipboard.items = [] }
        }
    }
}

struct NotificationsPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Notifications", blurb: "Mirror app notifications — and reply from the island.")
            Toggle("Mirror App Notifications", isOn: $model.prefs.mirrorAppNotifications)
            Toggle("Expand Notifications on Hover", isOn: $model.prefs.expandNotificationsOnHover)
            Toggle("Full-Size Notifications", isOn: $model.prefs.fullSizeNotifications)
            Slider(value: $model.prefs.notificationDuration, in: 1 ... 10) { Text("Notification Duration") }
            Toggle("Keep macOS Banner", isOn: $model.prefs.keepMacOSBanner)
            Toggle("Notifications-Only Mode", isOn: $model.prefs.notificationsOnlyMode)
            Toggle("Show After Native Banner", isOn: $model.prefs.showAfterNativeBanner)
        }
    }
}

struct CallsPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Calls & Messages", blurb: "Answer or decline FaceTime from the notch; WhatsApp, Teams, Zoom & other ringers surface too.")
            Toggle("Call Islands", isOn: $model.prefs.callIslands)
            Toggle("Show a caller’s photo on incoming FaceTime calls", isOn: $model.prefs.callerPhotos)
            Toggle("Message islands with quick reply", isOn: $model.prefs.messageReply)
            Toggle("Zoom, Meet, Teams, OBS won’t see the pill (or Cuely)", isOn: $model.prefs.hideFromMeetingCaptures)
        }
    }
}

struct FaceUnlockPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Face Unlock", blurb: "Face Unlock: look at your Mac to unlock it, all on-device.")
            Toggle("Face Unlock Is On", isOn: $model.prefs.faceUnlock)
            Toggle("Enrolled", isOn: $model.prefs.faceUnlockEnrolled)
            Toggle("Camera Guard", isOn: $model.prefs.cameraGuard)
            Toggle("An island the moment any app opens the camera", isOn: $model.prefs.cameraIsland)
            Text("A webcam can’t see depth. Mochy does not type your password. Use it for convenience, not on a Mac with sensitive data.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct LockScreenPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Lock Screen", blurb: "Lock the screen — click and hold to turn off the display.")
            Toggle("Briefly show an open lock in the pill when you unlock", isOn: $model.prefs.lockUnlockPill)
            Toggle("Lock Screen Widget", isOn: $model.prefs.lockScreenWidget)
            Button("Lock Screen") { model.lockScreen() }
        }
    }
}

struct TypingPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Typing Sounds", blurb: "A click on every key press — mechanical, typewriter and more.")
            Toggle("Typing Sounds On", isOn: $model.prefs.typingSounds)
            Picker("Profile", selection: $model.prefs.typingProfile) {
                Text("Cream").tag("Cream")
                Text("Box Navy").tag("Box Navy")
                Text("Typewriter").tag("Typewriter")
            }
            Toggle("Show pressed shortcuts as keycaps — for demos and screencasts", isOn: $model.prefs.keycapHUD)
            Toggle("Show only key combinations with ⌘, ⌃ or ⌥ — plain typing stays private", isOn: $model.prefs.onlyModifierCombos)
            ShortcutRow(action: ShortcutCatalog.all.first { $0.id == "typing" }!)
            Text("Needs Input Monitoring to hear key presses. Password fields stay silent.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onChange(of: model.prefs.typingSounds) { _, on in model.typing.enabled = on }
    }
}

struct PointerPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Pointer", blurb: "Theme your mouse pointer, add click ripples, a halo or a sparkle trail.")
            Toggle("Click Ripples", isOn: $model.prefs.clickRipples)
            Toggle("Pointer trail", isOn: $model.prefs.pointerTrail)
            Toggle("Halo", isOn: $model.prefs.pointerHalo)
            Toggle("Hold ⌃⌥ to dim everything except the area around the pointer", isOn: $model.prefs.spotlightOnControlOption)
        }
    }
}

struct CuelyPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Cuely", blurb: "A teleprompter in the notch — scroll a script while you present.")
            Toggle("Auto-Scroll", isOn: $model.prefs.cuelyAutoScroll)
            Toggle("Cuely can follow your voice", isOn: $model.prefs.cuelyFollowVoice)
            Slider(value: $model.prefs.cuelyFontSize, in: 14 ... 42) { Text("Font Size") }
            Slider(value: $model.prefs.cuelyScrollSpeed, in: 0.3 ... 3) { Text("Scroll speed") }
            Slider(value: $model.prefs.cuelyOpacity, in: 0.3 ... 1) { Text("Script Opacity") }
        }
    }
}

struct TimerPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Timer", blurb: "Countdowns, Pomodoro focus sessions and a stopwatch — live on the notch.")
            Slider(value: $model.prefs.pomodoroFocus, in: 5 ... 60) { Text("Focus Length \(Int(model.prefs.pomodoroFocus)) min") }
            Slider(value: $model.prefs.pomodoroBreak, in: 1 ... 30) { Text("Break Length \(Int(model.prefs.pomodoroBreak)) min") }
            Toggle("Timer Alerts", isOn: $model.prefs.timerAlerts)
            ShortcutRow(action: ShortcutCatalog.all.first { $0.id == "pomodoro" }!)
        }
    }
}

struct ActivityPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Activity", blurb: "A three-ring glance beside the collapsed notch.")
            Toggle("Activity Rings", isOn: $model.prefs.activityRings)
            Toggle("Activity Orb", isOn: $model.prefs.activityOrb)
            Toggle("Break Reminders", isOn: $model.prefs.breakReminders)
            Toggle("A reminder to get up and move", isOn: $model.prefs.standReminder)
            Toggle("A reminder to take a water break", isOn: $model.prefs.waterReminder)
            Toggle("A reminder to look away from the screen", isOn: $model.prefs.lookAwayReminder)
            Toggle("Block Apps While Focusing", isOn: $model.prefs.blockAppsWhileFocusing)
        }
    }
}

struct AIUsagePage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "AI Usage", blurb: "Usage from Claude, Codex, Cursor, Antigravity and Copilot, read on this Mac.")
            Toggle("Agent Permission Islands", isOn: $model.prefs.agentPermissionIslands)
            Toggle("AI Usage Alerts", isOn: $model.prefs.aiUsageAlerts)
            Toggle("AI Notification Sounds", isOn: $model.prefs.aiNotificationSounds)
            SecureField("Anthropic API key", text: $model.prefs.anthropicKey)
            Button("Refetch") { model.aiUsage.refresh() }
            ForEach(model.aiUsage.rows) { row in
                HStack { Text(row.name); Spacer(); Text(row.detail).foregroundStyle(.secondary) }
            }
        }
    }
}

struct PetPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Desktop Pet", blurb: "A tiny pet that reacts to music, charging, timers, and clicks.")
            Toggle("Show Mochi", isOn: $model.prefs.petOnDesktop)
            Toggle("Pet Visits Other Displays", isOn: $model.prefs.petVisitsOtherDisplays)
            Toggle("Pet Bedtime", isOn: $model.prefs.petBedtime)
            Toggle("Your pet waits in a bottom corner during Focus and Pomodoro sessions", isOn: $model.prefs.petHidesDuringFocus)
            Text(model.pet.statusLine)
            Button("Feed") { model.pet.feed() }
        }
    }
}

struct ConnectivityPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Connectivity", blurb: "AirPods, Bluetooth devices and network.")
            Toggle("AirPods islands", isOn: $model.prefs.airPodsIslands)
            Toggle("Autodetect AirPods when the case opens", isOn: $model.prefs.autodetectAirPods)
            Toggle("Connectivity Islands", isOn: $model.prefs.connectivityIslands)
            Toggle("Caps Lock HUD", isOn: $model.prefs.capsLockHUD)
            Toggle("Volume HUD", isOn: $model.prefs.volumeHUD)
            ForEach(model.bluetooth.devices, id: \.name) { device in
                Text("\(device.name) · connected")
            }
        }
    }
}

struct TerminalPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Terminal", blurb: "A full terminal running your shell in the notch.")
            Toggle("Nerd Fonts draw Powerlevel10k and Starship prompts properly", isOn: $model.prefs.nerdFont)
            Text("A real shell session lives in the Terminal tab.")
        }
    }
}

struct QuickSearchPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Quick Search", blurb: "Search the web from the notch — ⌘1–9 switches engine mid-query.")
            ForEach(model.prefs.searchEngines, id: \.self) { Text($0) }
        }
    }
}

struct StocksPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Stocks", blurb: "Add them in Settings › Stocks.")
            ForEach(model.stocks.quotes) { q in
                HStack { Text(q.id); Spacer(); Text(q.price); Text(q.change) }
            }
            Button("Refresh") { model.stocks.refresh() }
        }
    }
}

struct SpacesPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Spaces", blurb: "Your desktops as pills — click one to jump straight there.")
            Toggle("Spaces pills", isOn: $model.prefs.spacesPills)
            Toggle("A small, single-line island briefly shows the Space name", isOn: $model.prefs.spaceNameIsland)
            HStack {
                Button("Previous Space") { model.tools.switchSpace("left") }
                Button("Next Space") { model.tools.switchSpace("right") }
            }
        }
    }
}

struct KnockPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Knock", blurb: "Tap the trackpad for Knock actions, and take over the media keys.")
            Toggle("Knock", isOn: $model.prefs.knockEnabled)
        }
    }
}

struct WidgetsPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Widgets", blurb: "Clock, World Clock, Now Playing, Weather, Calendar, Batteries, System and Photo widgets on the desktop.")
            Toggle("Desktop widgets", isOn: $model.prefs.desktopWidgets)
            Toggle("Widget Glass", isOn: $model.prefs.widgetGlass)
            Toggle("Clock", isOn: $model.prefs.clockWidget)
            Toggle("World Clock", isOn: $model.prefs.worldClockWidget)
            Toggle("Weather", isOn: $model.prefs.weatherWidget)
            Toggle("Photo Widget", isOn: $model.prefs.photoWidget)
        }
    }
}

struct DeveloperPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "Developer", blurb: "Drive Mochy from scripts over 127.0.0.1:9999. Every request must carry the token below.")
            Toggle("Local API", isOn: $model.prefs.apiEnabled)
            Stepper("Port \(model.prefs.apiPort)", value: $model.prefs.apiPort, in: 1024 ... 65535)
            Text(model.prefs.apiToken).font(.system(.body, design: .monospaced))
            Button("Regenerate token") {
                model.prefs.apiToken = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24)).lowercased()
            }
            Toggle("Anonymous Analytics", isOn: $model.prefs.anonymousAnalytics)
            Toggle("Auto-Restart if Frozen", isOn: $model.prefs.autoRestartIfFrozen)
            ShortcutRow(action: ShortcutCatalog.all.first { $0.id == "emergency" }!)
            Text("POST /show  GET /status  POST /expand  header X-Mochy-Token")
                .font(.caption)
        }
    }
}

struct GalleryPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "All Tools", blurb: "Choose your tools in Settings › Tools, or take a guided tour.")
            ForEach(TabID.allCases) { tab in
                HStack {
                    Label(tab.title, systemImage: tab.symbol)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { model.enabledTabs.contains(tab) },
                        set: { on in
                            if on { model.enabledTabs.insert(tab) } else { model.enabledTabs.remove(tab) }
                            model.prefs.enabledTabs = model.enabledTabs.map(\.rawValue)
                        }
                    ))
                }
                Text(tab.blurb).font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Text("Overlays").font(.headline)
            ForEach(OverlayID.allCases) { overlay in
                Toggle(overlay.title, isOn: Binding(
                    get: { model.enabledOverlays.contains(overlay) },
                    set: { on in
                        if on { model.enabledOverlays.insert(overlay) } else { model.enabledOverlays.remove(overlay) }
                    }
                ))
            }
        }
    }
}

struct AboutPage: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(title: "About Mochy", blurb: "Version, updates, support links and resets.")
            Text("Mochy 1.1.0 — reconstructed from Notchy 2.0.0 settings surface. Original code; no Notchy assets or license keys.")
            Text("Charge limit, fan control, DDC brightness on external displays, MediaRemote private adapters, and Face Unlock password typing are not cloned — this Mac’s public APIs do not expose them.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Export Settings") {
                if let data = try? JSONEncoder().encode(model.prefs) {
                    let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].appendingPathComponent("mochy-settings.json")
                    try? data.write(to: url)
                }
            }
            Button("Factory reset") { model.factoryReset() }
        }
    }
}

struct ShortcutRow: View {
    @EnvironmentObject var model: AppModel
    let action: ShortcutAction
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(action.title)
                Text(action.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(model.prefs[keyPath: action.keyPath].display)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.08)))
            Toggle("", isOn: Binding(
                get: { model.prefs[keyPath: action.keyPath].enabled },
                set: { enabled in
                    var combo = model.prefs[keyPath: action.keyPath]
                    combo.enabled = enabled
                    model.prefs[keyPath: action.keyPath] = combo
                }
            ))
            .labelsHidden()
        }
    }
}
