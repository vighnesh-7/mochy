import Darwin
import Foundation

struct StatsSample: Equatable {
    var cpu: Double = 0
    var memoryUsed: UInt64 = 0
    var memoryTotal: UInt64 = ProcessInfo.processInfo.physicalMemory
    var networkIn: Double = 0
    var networkOut: Double = 0
    var diskFree: Int64 = 0
    var diskTotal: Int64 = 0

    var memoryFraction: Double { memoryTotal == 0 ? 0 : Double(memoryUsed) / Double(memoryTotal) }
    var diskUsedFraction: Double { diskTotal == 0 ? 0 : 1 - Double(diskFree) / Double(diskTotal) }
}

/// CPU, memory, network and disk sampled only while something on screen shows them.
@MainActor
final class SystemStatsService: ObservableObject {
    @Published private(set) var sample = StatsSample()
    @Published private(set) var cpuHistory: [Double] = []
    private var timer: Timer?
    private var previousTicks: [UInt64]?
    private var previousNetwork: (inBytes: UInt64, outBytes: UInt64, at: Date)?
    private var watchers = 0

    func beginWatching() {
        watchers += 1
        guard timer == nil else { return }
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func endWatching() {
        watchers = max(0, watchers - 1)
        guard watchers == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        var next = sample
        if let cpu = cpuUsage() { next.cpu = cpu }
        next.memoryUsed = memoryUsed()
        if let net = networkRates() {
            next.networkIn = net.0
            next.networkOut = net.1
        }
        if let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]) {
            next.diskFree = values.volumeAvailableCapacityForImportantUsage ?? 0
            next.diskTotal = Int64(values.volumeTotalCapacity ?? 0)
        }
        sample = next
        cpuHistory.append(next.cpu)
        if cpuHistory.count > 40 { cpuHistory.removeFirst(cpuHistory.count - 40) }
    }

    private func cpuUsage() -> Double? {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS, let info else { return nil }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
        var ticks: [UInt64] = []
        for cpu in 0 ..< Int(count) {
            let base = cpu * Int(CPU_STATE_MAX)
            ticks.append(UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)])))
            ticks.append(UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)])))
            ticks.append(UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])))
            ticks.append(UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)])))
        }
        defer { previousTicks = ticks }
        guard let previous = previousTicks, previous.count == ticks.count else { return nil }
        var busy: UInt64 = 0
        var total: UInt64 = 0
        for index in stride(from: 0, to: ticks.count, by: 4) {
            let delta = (0 ..< 4).map { ticks[index + $0] &- previous[index + $0] }
            busy += delta[0] + delta[1] + delta[2]
            total += delta[0] + delta[1] + delta[2] + delta[3]
        }
        return total == 0 ? 0 : Double(busy) / Double(total)
    }

    private func memoryUsed() -> UInt64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let page = UInt64(vm_kernel_page_size)
        let app = UInt64(stats.internal_page_count) - min(UInt64(stats.internal_page_count), UInt64(stats.purgeable_count))
        return (app + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * page
    }

    private func networkRates() -> (Double, Double)? {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return nil }
        defer { freeifaddrs(pointer) }
        var received: UInt64 = 0
        var sent: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            let name = String(cString: entry.pointee.ifa_name)
            if entry.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK), name.hasPrefix("en"),
               let data = entry.pointee.ifa_data?.assumingMemoryBound(to: if_data.self)
            {
                received += UInt64(data.pointee.ifi_ibytes)
                sent += UInt64(data.pointee.ifi_obytes)
            }
            cursor = entry.pointee.ifa_next
        }
        let now = Date()
        defer { previousNetwork = (received, sent, now) }
        guard let previous = previousNetwork, received >= previous.inBytes, sent >= previous.outBytes else { return nil }
        let seconds = max(now.timeIntervalSince(previous.at), 0.1)
        return (Double(received - previous.inBytes) / seconds, Double(sent - previous.outBytes) / seconds)
    }
}

enum ByteFormat {
    static func memory(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file) + "/s"
    }

    static func storage(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
