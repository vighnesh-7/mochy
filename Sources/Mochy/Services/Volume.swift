import AudioToolbox
import CoreAudio
import CoreGraphics
import Darwin
import Foundation

/// Follows the default output device's volume. Keyboard changes are polled because they often skip the property callback.
@MainActor
final class VolumeMonitor: ObservableObject {
    @Published private(set) var level: Float = 0
    @Published private(set) var muted = false
    @Published private(set) var changedAt = Date.distantPast

    private var device = AudioObjectID(kAudioObjectUnknown)
    private var started = false
    private var timer: Timer?
    private var baseline = false

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
        // Keyboard volume keys sometimes change the level without a property callback.
        // A short read keeps the island on the same number as the system HUD.
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.read(announce: true) }
        }
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
        guard device != AudioObjectID(kAudioObjectUnknown) else { return }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let volumeOK = AudioObjectGetPropertyData(device, &Self.volumeAddress, 0, nil, &size, &value) == noErr
        var mute: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        let muteOK = AudioObjectGetPropertyData(device, &Self.muteAddress, 0, nil, &size, &mute) == noErr
        let nextMute = muteOK && mute != 0
        let changed = volumeOK && (abs(value - level) > 0.005 || nextMute != muted)
        if volumeOK { level = value }
        if muteOK { muted = nextMute }
        if !baseline {
            baseline = true
            return
        }
        if announce, changed { changedAt = Date() }
    }
}

/// The built-in display's brightness, the same value the keyboard keys change.
@MainActor
final class BrightnessMonitor: ObservableObject {
    @Published private(set) var level: Float = 1
    @Published private(set) var available = false
    @Published private(set) var changedAt = Date.distantPast

    private var timer: Timer?
    private var baseline = false
    private let getBrightness: (@convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32)?

    init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
        getBrightness = handle.flatMap { dlsym($0, "DisplayServicesGetBrightness") }.map {
            unsafeBitCast($0, to: (@convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32).self)
        }
    }

    func start() {
        guard timer == nil else { return }
        read()
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.read() }
        }
    }

    private func read() {
        guard let getBrightness else { return }
        var value: Float = 0
        let status = getBrightness(CGMainDisplayID(), &value)
        guard status == 0, value >= 0, value <= 1 else { return }
        let changed = abs(value - level) > 0.005
        level = value
        available = true
        if !baseline {
            baseline = true
            return
        }
        if changed { changedAt = Date() }
    }
}
