import AudioToolbox
import CoreAudio
import Foundation

/// Follows the default output device's volume without polling or key monitoring.
@MainActor
final class VolumeMonitor: ObservableObject {
    @Published private(set) var level: Float = 0
    @Published private(set) var muted = false
    @Published private(set) var changedAt = Date.distantPast

    private var device = AudioObjectID(kAudioObjectUnknown)
    private var started = false

    private static var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    private static var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    private static var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    func start() {
        guard !started else { return }
        started = true
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &Self.defaultDeviceAddress, .main) { [weak self] _, _ in
            Task { @MainActor in self?.attach() }
        }
        attach()
    }

    private func attach() {
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &Self.defaultDeviceAddress, 0, nil, &size, &id) == noErr else { return }
        guard id != device else { return }
        device = id
        AudioObjectAddPropertyListenerBlock(id, &Self.volumeAddress, .main) { [weak self] _, _ in
            Task { @MainActor in self?.read(announce: true) }
        }
        AudioObjectAddPropertyListenerBlock(id, &Self.muteAddress, .main) { [weak self] _, _ in
            Task { @MainActor in self?.read(announce: true) }
        }
        read(announce: false)
    }

    private func read(announce: Bool) {
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        if AudioObjectGetPropertyData(device, &Self.volumeAddress, 0, nil, &size, &value) == noErr { level = value }
        var mute: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectGetPropertyData(device, &Self.muteAddress, 0, nil, &size, &mute) == noErr { muted = mute != 0 }
        if announce { changedAt = Date() }
    }
}
