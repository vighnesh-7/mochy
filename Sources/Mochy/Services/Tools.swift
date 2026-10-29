import AppKit
import CoreLocation
import Foundation
import ServiceManagement

@MainActor
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var temperature: String?
    @Published private(set) var condition = ""
    @Published private(set) var symbol = "cloud.sun.fill"
    @Published private(set) var range = ""
    @Published private(set) var needsPermission = false
    private let manager = CLLocationManager()
    private var lastFetch = Date.distantPast

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func refreshIfStale() {
        guard Date().timeIntervalSince(lastFetch) > 20 * 60 else { return }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted: needsPermission = true
        default: manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            self.needsPermission = status == .denied || status == .restricted
            if !self.needsPermission, status != .notDetermined { manager.requestLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.fetch(location.coordinate) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    private func fetch(_ coordinate: CLLocationCoordinate2D) {
        lastFetch = Date()
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(coordinate.latitude)&longitude=\(coordinate.longitude)&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1")!
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any], let temp = current["temperature_2m"] as? Double
            else { return }
            let code = current["weather_code"] as? Int ?? 0
            let daily = json["daily"] as? [String: Any]
            let high = (daily?["temperature_2m_max"] as? [Double])?.first
            let low = (daily?["temperature_2m_min"] as? [Double])?.first
            Task { @MainActor in
                self.temperature = String(format: "%.0f°", temp)
                (self.condition, self.symbol) = Self.describe(code)
                if let high, let low { self.range = String(format: "H %.0f°  L %.0f°", high, low) }
            }
        }.resume()
    }

    private static func describe(_ code: Int) -> (String, String) {
        switch code {
        case 0: ("Clear", "sun.max.fill")
        case 1, 2: ("Partly Cloudy", "cloud.sun.fill")
        case 3: ("Cloudy", "cloud.fill")
        case 45, 48: ("Fog", "cloud.fog.fill")
        case 51 ... 67, 80 ... 82: ("Rain", "cloud.rain.fill")
        case 71 ... 77, 85, 86: ("Snow", "cloud.snow.fill")
        case 95 ... 99: ("Thunderstorm", "cloud.bolt.rain.fill")
        default: ("Weather", "cloud.sun.fill")
        }
    }
}

@MainActor
final class NotesService: ObservableObject {
    @Published var text = "" { didSet { scheduleSave() } }
    private var pending: DispatchWorkItem?

    private var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Mochy", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("scratchpad.txt")
    }

    func load() { text = (try? String(contentsOf: url, encoding: .utf8)) ?? "" }

    private func scheduleSave() {
        pending?.cancel()
        let snapshot = text
        let target = url
        let work = DispatchWorkItem { try? snapshot.write(to: target, atomically: true, encoding: .utf8) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
}

@MainActor
final class CalculatorService: ObservableObject {
    @Published var input = ""
    @Published private(set) var history: [String] = []

    var result: String? {
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/()% ")
        let expression = input.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/")
        guard !expression.isEmpty, expression.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        let prepared = expression.replacingOccurrences(of: "%", with: "*0.01")
        guard let value = (NSExpression(format: prepared).expressionValue(with: nil, context: nil) as? NSNumber)?.doubleValue, value.isFinite else { return nil }
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 8
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value))
    }

    func commit() {
        guard let result else { return }
        history.insert("\(input) = \(result)", at: 0)
        history = Array(history.prefix(8))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result, forType: .string)
        input = ""
    }
}

@MainActor
final class LauncherService: ObservableObject {
    struct App: Identifiable {
        let id: URL
        let name: String
    }

    @Published var query = ""
    @Published private(set) var apps: [App] = []

    func load() {
        guard apps.isEmpty else { return }
        let folders = ["/Applications", "/System/Applications", "/System/Applications/Utilities", NSHomeDirectory() + "/Applications"]
        var found: [App] = []
        for folder in folders {
            let urls = (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil)) ?? []
            found += urls.filter { $0.pathExtension == "app" }.map { App(id: $0, name: $0.deletingPathExtension().lastPathComponent) }
        }
        apps = found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var results: [App] {
        let list = query.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
        return Array(list.prefix(24))
    }

    func open(_ app: App) {
        NSWorkspace.shared.openApplication(at: app.id, configuration: NSWorkspace.OpenConfiguration())
    }
}

@MainActor
enum SystemActions {
    static func screenshot() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-iU"]
        try? task.run()
    }

    static func pickColor(completion: @escaping (String) -> Void) {
        NSColorSampler().show { color in
            guard let color = color?.usingColorSpace(.sRGB) else { return }
            let hex = String(format: "#%02X%02X%02X", Int(color.redComponent * 255), Int(color.greenComponent * 255), Int(color.blueComponent * 255))
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hex, forType: .string)
            Task { @MainActor in completion(hex) }
        }
    }

    static func lockScreen() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["displaysleepnow"]
        try? task.run()
    }

    static func search(_ query: String, engine: String) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let template: String
        switch engine {
        case "YouTube": template = "https://www.youtube.com/results?search_query="
        case "GitHub": template = "https://github.com/search?q="
        case "DuckDuckGo": template = "https://duckduckgo.com/?q="
        default: template = "https://www.google.com/search?q="
        }
        if let url = URL(string: template + encoded) { NSWorkspace.shared.open(url) }
    }
}

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns a message when macOS refuses, for example for an unsigned build outside /Applications.
    static func set(_ enabled: Bool) -> String? {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
