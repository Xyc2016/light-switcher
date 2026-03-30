import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

public final class WindowSwitchService: @unchecked Sendable {
    private let permissionsService: PermissionsService

    public init(permissionsService: PermissionsService) {
        self.permissionsService = permissionsService
    }

    public func activate(_ snapshot: WindowSnapshot) {
        guard let app = NSRunningApplication(processIdentifier: snapshot.pid) else {
            return
        }

        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

        guard permissionsService.isAccessibilityTrusted(prompt: false) else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            self?.focusBestMatchingWindow(snapshot)
        }
    }

    private func focusBestMatchingWindow(_ snapshot: WindowSnapshot) {
        let appElement = AXUIElementCreateApplication(snapshot.pid)
        guard let windows = copyWindows(from: appElement) else {
            return
        }

        let target = windows
            .map { window in (window, self.score(window: window, snapshot: snapshot)) }
            .max { $0.1 < $1.1 }

        guard let bestMatch = target, bestMatch.1 > 0 else {
            return
        }

        focus(window: bestMatch.0)
    }

    private func copyWindows(from appElement: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let windows = value as? [AXUIElement] else {
            return nil
        }

        return windows
    }

    private func score(window: AXUIElement, snapshot: WindowSnapshot) -> Int {
        if isMinimized(window) {
            return 0
        }

        var score = 0

        if let title = copyString(window, attribute: kAXTitleAttribute), title == snapshot.title {
            score += 100
        }

        if let frame = copyFrame(window) {
            if approximatelyEqual(frame.origin.x, snapshot.bounds.origin.x) &&
                approximatelyEqual(frame.origin.y, snapshot.bounds.origin.y)
            {
                score += 50
            }

            if approximatelyEqual(frame.size.width, snapshot.bounds.size.width) &&
                approximatelyEqual(frame.size.height, snapshot.bounds.size.height)
            {
                score += 40
            }
        }

        return score
    }

    private func isMinimized(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &value)
        guard result == .success else {
            return false
        }

        return (value as? Bool) ?? false
    }

    private func copyString(_ window: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, attribute as CFString, &value)
        guard result == .success else {
            return nil
        }

        return value as? String
    }

    private func copyFrame(_ window: AXUIElement) -> CGRect? {
        guard
            let positionValue = copyAXValue(window, attribute: kAXPositionAttribute, type: .cgPoint),
            let sizeValue = copyAXValue(window, attribute: kAXSizeAttribute, type: .cgSize)
        else {
            return nil
        }

        var origin = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue, .cgPoint, &origin)
        AXValueGetValue(sizeValue, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }

    private func copyAXValue(_ window: AXUIElement, attribute: String, type: AXValueType) -> AXValue? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, attribute as CFString, &value)
        guard result == .success, let axValue = value as? AXValue, AXValueGetType(axValue) == type else {
            return nil
        }

        return axValue
    }

    private func focus(window: AXUIElement) {
        let trueValue = kCFBooleanTrue
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, trueValue)
        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, trueValue)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    private func approximatelyEqual(_ lhs: CGFloat, _ rhs: CGFloat, tolerance: CGFloat = 6) -> Bool {
        abs(lhs - rhs) <= tolerance
    }
}
