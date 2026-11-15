import Foundation
import IOBluetooth

/// Watches Bluetooth audio devices so Mochy can show a dock-adjacent AirPods chip on connect.
@MainActor
final class AudioDeviceMonitor: NSObject, ObservableObject {
    @Published private(set) var connectedName: String?
    @Published private(set) var isAirPods = false
    @Published private(set) var symbol = "dot.radiowaves.right"
    /// Briefly true after a device joins, so the dock chip can show a green pop.
    @Published private(set) var showGlow = false
    @Published var announce: String?

    private var connectNote: IOBluetoothUserNotification?
    private var disconnectNotes: [IOBluetoothUserNotification] = []
    private var glowToken = 0

    func start() {
        guard connectNote == nil else { return }
        connectNote = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(didConnect(_:device:)))
        refresh()
    }

    func stop() {
        connectNote?.unregister()
        connectNote = nil
        disconnectNotes.forEach { $0.unregister() }
        disconnectNotes.removeAll()
    }

    @objc private func didConnect(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let note = device.register(forDisconnectNotification: self, selector: #selector(didDisconnect(_:device:)))
        if let note { disconnectNotes.append(note) }
        Task { @MainActor in
            self.apply(device, announce: true)
        }
    }

    @objc private func didDisconnect(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        notification.unregister()
        disconnectNotes.removeAll { $0 === notification }
        Task { @MainActor in self.refresh() }
    }

    private func refresh() {
        disconnectNotes.forEach { $0.unregister() }
        disconnectNotes.removeAll()
        let devices = ((IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []).filter { $0.isConnected() }
        if let first = devices.first {
            apply(first, announce: false)
            for device in devices {
                if let note = device.register(forDisconnectNotification: self, selector: #selector(didDisconnect(_:device:))) {
                    disconnectNotes.append(note)
                }
            }
        } else {
            connectedName = nil
            isAirPods = false
            symbol = "dot.radiowaves.right"
            showGlow = false
        }
    }

    private func apply(_ device: IOBluetoothDevice, announce: Bool) {
        let name = device.name ?? "Bluetooth Device"
        connectedName = name
        isAirPods = name.localizedCaseInsensitiveContains("airpods")
        symbol = Self.symbol(for: device)
        guard announce else { return }
        self.announce = name
        showGlow = true
        glowToken += 1
        let token = glowToken
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            if self.glowToken == token { self.showGlow = false }
        }
    }

    private static func symbol(for device: IOBluetoothDevice) -> String {
        let name = device.name ?? ""
        if name.localizedCaseInsensitiveContains("airpods") { return "airpodspro" }
        if device.deviceClassMajor == UInt32(kBluetoothDeviceClassMajorAudio) { return "headphones" }
        if device.deviceClassMajor == UInt32(kBluetoothDeviceClassMajorPeripheral) { return "keyboard" }
        return "dot.radiowaves.right"
    }
}
