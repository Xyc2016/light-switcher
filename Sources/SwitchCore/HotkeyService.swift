import AppKit
import Carbon
import Foundation

public struct HotkeyConfiguration: Sendable {
    public let keyCode: UInt32
    public let carbonModifiers: UInt32
    public let requiredModifier: NSEvent.ModifierFlags

    public init(
        keyCode: UInt32 = UInt32(kVK_Tab),
        carbonModifiers: UInt32 = UInt32(optionKey),
        requiredModifier: NSEvent.ModifierFlags = [.option]
    ) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.requiredModifier = requiredModifier
    }
}

public final class HotkeyService: @unchecked Sendable {
    public var onHotkeyPressed: (() -> Void)?
    public var onModifierReleased: (() -> Void)?

    private let configuration: HotkeyConfiguration
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var releaseMonitor: DispatchSourceTimer?

    public init(configuration: HotkeyConfiguration = HotkeyConfiguration()) {
        self.configuration = configuration
    }

    deinit {
        stopReleaseMonitoring()
        unregister()
    }

    public func register() {
        unregister()

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let userData, let eventRef else {
                    return noErr
                }

                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                return service.handleHotkey(eventRef)
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard handlerStatus == noErr else {
            return
        }

        var hotKeyID = EventHotKeyID(signature: fourCharCode(from: "LTSW"), id: 1)
        RegisterEventHotKey(
            configuration.keyCode,
            configuration.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    public func startReleaseMonitoring() {
        guard releaseMonitor == nil else {
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.02, repeating: 0.02)
        timer.setEventHandler { [weak self] in
            guard let self else {
                return
            }

            if !NSEvent.modifierFlags.contains(self.configuration.requiredModifier) {
                self.stopReleaseMonitoring()
                self.onModifierReleased?()
            }
        }
        timer.resume()
        releaseMonitor = timer
    }

    public func stopReleaseMonitoring() {
        releaseMonitor?.cancel()
        releaseMonitor = nil
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func handleHotkey(_ eventRef: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr, hotKeyID.id == 1 else {
            return noErr
        }

        onHotkeyPressed?()
        return noErr
    }

    private func fourCharCode(from string: String) -> OSType {
        string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }
}
