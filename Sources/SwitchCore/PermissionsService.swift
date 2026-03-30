@preconcurrency import ApplicationServices
import AppKit
import Foundation

public final class PermissionsService: @unchecked Sendable {
    public init() {}

    public func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let promptKey = unsafeBitCast(kAXTrustedCheckOptionPrompt, to: CFString.self) as String
        let options = [promptKey: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
