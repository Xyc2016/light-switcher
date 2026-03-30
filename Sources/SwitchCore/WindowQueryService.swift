import CoreGraphics
import Foundation

public protocol WindowQuerying: Sendable {
    func snapshotVisibleWindows(excludingPID: pid_t) -> [WindowSnapshot]
}

public final class WindowQueryService: WindowQuerying, @unchecked Sendable {
    public init() {}

    public func snapshotVisibleWindows(excludingPID: pid_t) -> [WindowSnapshot] {
        guard
            let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[CFString: Any]]
        else {
            return []
        }

        let records = infoList.map(Self.makeRecord)
        return WindowListFilter.filter(records: records, excludingPID: excludingPID)
    }

    private static func makeRecord(dictionary: [CFString: Any]) -> WindowRecord {
        let bounds: CGRect?
        if let boundsDict = dictionary[kCGWindowBounds] as? CFDictionary {
            bounds = CGRect(dictionaryRepresentation: boundsDict)
        } else {
            bounds = nil
        }

        return WindowRecord(
            windowID: dictionary[kCGWindowNumber] as? CGWindowID,
            ownerPID: dictionary[kCGWindowOwnerPID] as? pid_t,
            ownerName: dictionary[kCGWindowOwnerName] as? String,
            title: dictionary[kCGWindowName] as? String,
            layer: dictionary[kCGWindowLayer] as? Int,
            alpha: dictionary[kCGWindowAlpha] as? Double,
            bounds: bounds,
            isOnscreen: dictionary[kCGWindowIsOnscreen] as? Bool
        )
    }
}
