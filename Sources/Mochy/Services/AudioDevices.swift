import Foundation
import IOBluetooth

/// Watches Bluetooth audio devices so Mochy can show a dock-adjacent AirPods chip on connect.
@MainActor
final class AudioDeviceMonitor: NSObject, ObservableObject {
    @Published private(set) var connectedName: String?
    @Published private(set) var isAirPods = false
    @Published var announce: String?

    private var connectNote: IOBluetoothUserNotification?
    private var disconnectNotes: [IOBluetoothUserNotification] = []

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
        guard isAudio(device) else { return }
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
        let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        let audio = devices.filter { $0.isConnected() && isAudio($0) }
        if let first = audio.first {
            apply(first, announce: false)
            for device in audio {
                if let note = device.register(forDisconnectNotification: self, selector: #selector(didDisconnect(_:device:))) {
                    disconnectNotes.append(note)
                }
            }
        } else {
            connectedName = nil
            isAirPods = false
        }
    }

    private func apply(_ device: IOBluetoothDevice, announce: Bool) {
        let name = device.name ?? "Audio Device"
        connectedName = name
        isAirPods = name.localizedCaseInsensitiveContains("airpods")
        if announce {
            self.announce = name
        }
    }

    private func isAudio(_ device: IOBluetoothDevice) -> Bool {
        if (device.name ?? "").localizedCaseInsensitiveContains("airpods") { return true }
        return device.deviceClassMajor == UInt32(kBluetoothDeviceClassMajorAudio)
    }
}
