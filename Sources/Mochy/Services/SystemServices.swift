import AppKit
import CoreLocation
import Foundation
import IOBluetooth
import IOKit.ps
import IOKit.pwr_mgt

@MainActor
final class BatteryService: ObservableObject {
    @Published var percent: Int = 100
    @Published var isCharging = false
    @Published var isPluggedIn = false
    @Published var timeRemaining: String = "—"
    @Published var health: String = "—"
    @Published var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    private var lastCharging = false
    var onChargingChange: ((Bool, Int) -> Void)?
    var onLowBattery: ((Int) -> Void)?

    func refresh() {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return }
        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] else { continue }
            let capacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
            let max = max(desc[kIOPSMaxCapacityKey] as? Int ?? 100, 1)
            percent = Int((Double(capacity) / Double(max)) * 100)
            let state = desc[kIOPSPowerSourceStateKey] as? String
            isPluggedIn = state == kIOPSACPowerValue
            isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            if let minutes = desc[kIOPSTimeToEmptyKey] as? Int, minutes > 0, !isCharging {
                timeRemaining = "\(minutes / 60)h \(minutes % 60)m"
            } else if let minutes = desc[kIOPSTimeToFullChargeKey] as? Int, minutes > 0, isCharging {
                timeRemaining = "\(minutes) min to full"
            } else {
                timeRemaining = isCharging ? "Charging" : "On battery"
            }
            if let healthVal = desc["BatteryHealth"] as? String {
                health = healthVal
            }
            break
        }
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        if isCharging != lastCharging {
            onChargingChange?(isCharging, percent)
            lastCharging = isCharging
        }
        if !isCharging, percent <= 20 {
            onLowBattery?(percent)
        }
    }
}

@MainActor
final class CaffeineService: ObservableObject {
    @Published var isActive = false
    private var assertionID: IOPMAssertionID = 0

    func toggle() {
        if isActive { off() } else { on() }
    }

    func on() {
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Mochy Caffeine" as CFString,
            &id
        )
        if result == kIOReturnSuccess {
            assertionID = id
            isActive = true
        }
    }

    func off() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        isActive = false
    }
}

@MainActor
final class BluetoothService: ObservableObject {
    @Published var devices: [(name: String, connected: Bool)] = []
    @Published var wifiName: String = "Wi-Fi"

    func refresh() {
        var found: [(String, Bool)] = []
        if let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
            for device in paired where device.isConnected() {
                found.append((device.name ?? "Bluetooth device", true))
            }
        }
        devices = found
        wifiName = currentSSID() ?? "Wi-Fi"
    }

    private func currentSSID() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        task.arguments = ["-getairportnetwork", "en0"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard text.contains("Current Wi-Fi Network:") else { return nil }
        return text.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var temperature: String = "—"
    @Published var condition: String = "Weather"
    @Published var city: String = ""
    @Published var forecast: String = ""
    private let manager = CLLocationManager()
    private var asked = false

    override init() {
        super.init()
        manager.delegate = self
    }

    func request() {
        if !asked {
            asked = true
            manager.requestWhenInUseAuthorization()
        }
        if let loc = manager.location {
            fetch(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
        } else if !city.isEmpty {
            fetchCity(city)
        } else {
            manager.requestLocation()
        }
    }

    func fetchCity(_ name: String) {
        city = name
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1")
        else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let lat = first["latitude"] as? Double,
                  let lon = first["longitude"] as? Double
            else { return }
            Task { @MainActor in self.fetch(lat: lat, lon: lon) }
        }.resume()
    }

    func fetch(lat: Double, lon: Double) {
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min&timezone=auto")!
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any],
                  let temp = current["temperature_2m"] as? Double
            else { return }
            let code = current["weather_code"] as? Int ?? 0
            Task { @MainActor in
                self.temperature = String(format: "%.0f°", temp)
                self.condition = Self.label(for: code)
                if let daily = json["daily"] as? [String: Any],
                   let max = (daily["temperature_2m_max"] as? [Double])?.first,
                   let min = (daily["temperature_2m_min"] as? [Double])?.first
                {
                    self.forecast = String(format: "H %.0f°  L %.0f°", max, min)
                }
            }
        }.resume()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.fetch(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    private static func label(for code: Int) -> String {
        switch code {
        case 0: "Clear"
        case 1, 2: "Partly cloudy"
        case 3: "Overcast"
        case 45, 48: "Fog"
        case 51 ... 67: "Rain"
        case 71 ... 77: "Snow"
        case 80 ... 82: "Showers"
        case 95 ... 99: "Thunder"
        default: "Weather"
        }
    }
}

@MainActor
final class InputMonitor: ObservableObject {
    @Published var capsLock = false
    private var flagsMonitor: Any?
    private var keyMonitor: Any?
    var onCapsLock: ((Bool) -> Void)?
    var onVolumeKey: ((Int) -> Void)?
    var onBrightnessKey: ((Int) -> Void)?
    var onKey: ((UInt16, NSEvent) -> Void)?
    private var brightness: Int = 70

    func start() {
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                let on = event.modifierFlags.contains(.capsLock)
                guard let self else { return }
                if on != self.capsLock {
                    self.capsLock = on
                    self.onCapsLock?(on)
                }
            }
        }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            let key = Int32((event.data1 & 0xFFFF_0000) >> 16)
            let state = (event.data1 & 0xFF00) >> 8
            guard state == 0x0A else { return }
            Task { @MainActor in
                if key == 0 || key == 1 || key == 7 {
                    self?.onVolumeKey?(Self.systemVolume())
                } else if key == 2 || key == 3 || key == 21 || key == 22 {
                    if key == 2 || key == 21 { self?.brightness = min(100, (self?.brightness ?? 70) + 6) }
                    else { self?.brightness = max(0, (self?.brightness ?? 70) - 6) }
                    self?.onBrightnessKey?(self?.brightness ?? 70)
                }
            }
        }
        _ = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.onKey?(event.keyCode, event)
            }
        }
    }

    static func systemVolume() -> Int {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", "output volume of (get volume settings)"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "50"
        return Int(text) ?? 50
    }

    static func setVolume(_ value: Int) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", "set volume output volume \(max(0, min(100, value)))"]
        try? task.run()
    }
}

@MainActor
final class FolderWatcher: ObservableObject {
    @Published var downloads: [URL] = []
    @Published var screenshots: [URL] = []
    private var sources: [DispatchSourceFileSystemObject] = []
    var onDownload: ((URL) -> Void)?
    var onScreenshot: ((URL) -> Void)?

    func start() {
        let dl = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        if let dl { watch(dl, download: true) }
        if let desktop { watch(desktop, download: false) }
        refresh()
    }

    func refresh() {
        let fm = FileManager.default
        if let dl = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first,
           let items = try? fm.contentsOfDirectory(at: dl, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
        {
            downloads = Array(items.sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da > db
            }.prefix(20))
        }
        if let desktop = fm.urls(for: .desktopDirectory, in: .userDomainMask).first,
           let items = try? fm.contentsOfDirectory(at: desktop, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
        {
            screenshots = items.filter { $0.lastPathComponent.lowercased().contains("screenshot") }
                .sorted { a, b in
                    let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return da > db
                }
        }
    }

    private func watch(_ url: URL, download: Bool) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .extend], queue: .main)
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.refresh()
                if download, let latest = self?.downloads.first {
                    self?.onDownload?(latest)
                } else if !download, let latest = self?.screenshots.first {
                    self?.onScreenshot?(latest)
                }
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        sources.append(source)
    }
}

@MainActor
final class ClipboardService: ObservableObject {
    struct Item: Identifiable {
        let id = UUID()
        let text: String
        let date = Date()
    }

    @Published var items: [Item] = []
    private var lastChange = NSPasteboard.general.changeCount

    func poll(limit: Int = 50) {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChange else { return }
        lastChange = pb.changeCount
        if let text = pb.string(forType: .string), !text.isEmpty {
            items.insert(Item(text: String(text.prefix(2000))), at: 0)
            items = Array(items.prefix(limit))
        }
    }

    func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        lastChange = pb.changeCount
    }
}
