import Carbon.HIToolbox
import Foundation

/// System-wide shortcuts through Carbon hot keys. They work without Accessibility access
/// and the key press is consumed, so it never reaches the frontmost app.
@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var refs: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var handlerInstalled = false
    private(set) var failures: [String] = []

    func register(_ bindings: [(combo: KeyCombo, name: String, action: () -> Void)]) {
        unregisterAll()
        installHandlerIfNeeded()
        failures = []
        for (index, binding) in bindings.enumerated() {
            let id = UInt32(index + 1)
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: OSType(0x4D4F4359), id: id) // 'MOCY'
            let status = RegisterEventHotKey(binding.combo.keyCode, binding.combo.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                refs.append(ref)
                actions[id] = binding.action
            } else {
                failures.append(binding.name)
            }
        }
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        actions.removeAll()
    }

    fileprivate func fire(_ id: UInt32) {
        actions[id]?()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKey = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
            let id = hotKey.id
            DispatchQueue.main.async { HotKeyCenter.shared.fire(id) }
            return noErr
        }, 1, &spec, nil, nil)
        handlerInstalled = true
    }
}
