import AppKit
import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt

struct BatteryVitals: Equatable {
    var hasBattery = false
    var percent = 100
    var isCharging = false
    var isPluggedIn = false
    var isFull = false
    var minutesRemaining: Int?
    var cycleCount: Int?
    var healthPercent: Int?
    var designCapacity: Int?
    var maxCapacity: Int?
    var temperatureC: Double?
    var voltage: Double?
    var amperage: Double?
    var adapterWatts: Int?
    var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

    /// Positive while charging, negative while draining.
    var watts: Double? {
        guard let voltage, let amperage else { return nil }
        return voltage * amperage
    }

    var timeDescription: String {
        if isFull, isPluggedIn { return "Fully charged" }
        guard let minutes = minutesRemaining, minutes > 0, minutes < 60 * 24 else {
            return isCharging ? "Charging" : (isPluggedIn ? "Not charging" : "On battery")
        }
        let text = minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
        return isCharging ? "\(text) until full" : "\(text) left"
    }
}

@MainActor
final class BatteryMonitor: ObservableObject {
    @Published private(set) var vitals = BatteryVitals()
    var onPowerChange: ((BatteryVitals, BatteryVitals) -> Void)?
    private var source: CFRunLoopSource?
    private var ticker: Timer?

    func start() {
        refresh()
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let loop = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in monitor.refresh() }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), loop, .commonModes)
            source = loop
        }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        let previous = vitals
        var next = BatteryVitals()
        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        {
            for source in list {
                guard let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                      (desc[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType
                else { continue }
                next.hasBattery = true
                let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
                let max = Swift.max(desc[kIOPSMaxCapacityKey] as? Int ?? 100, 1)
                next.percent = Int((Double(current) / Double(max) * 100).rounded())
                next.isPluggedIn = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
                next.isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
                next.isFull = desc[kIOPSIsChargedKey] as? Bool ?? false
                let key = next.isCharging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
                if let minutes = desc[key] as? Int, minutes > 0 { next.minutesRemaining = minutes }
            }
        }
        readRegistry(into: &next)
        next.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        guard next != previous else { return }
        vitals = next
        onPowerChange?(previous, next)
    }

    private func readRegistry(into vitals: inout BatteryVitals) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        var unmanaged: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = unmanaged?.takeRetainedValue() as? [String: Any]
        else { return }
        func int(_ key: String) -> Int? { (props[key] as? NSNumber)?.intValue }
        vitals.cycleCount = int("CycleCount")
        vitals.designCapacity = int("DesignCapacity")
        vitals.maxCapacity = int("AppleRawMaxCapacity") ?? int("NominalChargeCapacity")
        if let design = vitals.designCapacity, design > 0, let max = vitals.maxCapacity {
            vitals.healthPercent = min(100, Int((Double(max) / Double(design) * 100).rounded()))
        }
        if let current = int("AppleRawCurrentCapacity") ?? int("CurrentCapacity"),
           let max = int("AppleRawMaxCapacity") ?? int("MaxCapacity"), max > 0
        {
            vitals.percent = min(100, Int((Double(current) / Double(max) * 100).rounded()))
        }
        if int("IsCharging") == 1 { vitals.isCharging = true }
        if let raw = int("Temperature") { vitals.temperatureC = Double(raw) / 100 }
        if let mv = int("Voltage") { vitals.voltage = Double(mv) / 1000 }
        if let number = props["Amperage"] as? NSNumber {
            vitals.amperage = Double(Int64(truncatingIfNeeded: number.int64Value)) / 1000
        }
        if let adapter = props["AdapterDetails"] as? [String: Any], let watts = (adapter["Watts"] as? NSNumber)?.intValue, watts > 0 {
            vitals.adapterWatts = watts
        }
    }
}

@MainActor
final class CaffeineService: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var endsAt: Date?
    private var assertion: IOPMAssertionID = 0
    private var expiry: DispatchWorkItem?

    func toggle(duration: CaffeineDuration, keepDisplayOn: Bool) {
        if isActive { stop() } else { start(duration: duration, keepDisplayOn: keepDisplayOn) }
    }

    func start(duration: CaffeineDuration, keepDisplayOn: Bool) {
        stop()
        let type = keepDisplayOn ? kIOPMAssertionTypePreventUserIdleDisplaySleep : kIOPMAssertionTypePreventUserIdleSystemSleep
        var id: IOPMAssertionID = 0
        guard IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "Mochy Caffeine" as CFString, &id) == kIOReturnSuccess else { return }
        assertion = id
        isActive = true
        if duration != .indefinitely {
            let end = Date().addingTimeInterval(TimeInterval(duration.rawValue * 60))
            endsAt = end
            let work = DispatchWorkItem { [weak self] in self?.stop() }
            expiry = work
            DispatchQueue.main.asyncAfter(deadline: .now() + end.timeIntervalSinceNow, execute: work)
        }
    }

    func stop() {
        expiry?.cancel()
        expiry = nil
        if assertion != 0 {
            IOPMAssertionRelease(assertion)
            assertion = 0
        }
        isActive = false
        endsAt = nil
    }

    var remainingDescription: String {
        guard let endsAt else { return "On" }
        let minutes = max(0, Int(endsAt.timeIntervalSinceNow / 60))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
