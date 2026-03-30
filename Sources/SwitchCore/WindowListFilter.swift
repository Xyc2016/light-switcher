import CoreGraphics
import Foundation

public enum WindowListFilter {
    private static let excludedOwners: Set<String> = [
        "Control Center",
        "Dock",
        "Notification Center",
        "SystemUIServer",
        "universalAccessAuthWarn",
        "Window Server",
    ]

    public static func filter(records: [WindowRecord], excludingPID: pid_t) -> [WindowSnapshot] {
        var seen = Set<CGWindowID>()
        var snapshots: [WindowSnapshot] = []

        for record in records {
            guard
                let windowID = record.windowID,
                let pid = record.ownerPID,
                let appName = trimmed(record.ownerName),
                let bounds = record.bounds
            else {
                continue
            }

            guard pid != excludingPID else {
                continue
            }

            guard !excludedOwners.contains(appName) else {
                continue
            }

            guard record.layer == 0 else {
                continue
            }

            if let isOnscreen = record.isOnscreen, !isOnscreen {
                continue
            }

            if let alpha = record.alpha, alpha <= 0 {
                continue
            }

            guard bounds.width > 1, bounds.height > 1 else {
                continue
            }

            guard seen.insert(windowID).inserted else {
                continue
            }

            let exactTitle = trimmed(record.title)
            let snapshot = WindowSnapshot(
                windowID: windowID,
                pid: pid,
                appName: appName,
                title: exactTitle ?? appName,
                bounds: bounds,
                hasExactTitle: exactTitle != nil
            )

            if let duplicateIndex = snapshots.firstIndex(where: {
                $0.pid == snapshot.pid && approximatelyEqual($0.bounds, snapshot.bounds)
            }) {
                if snapshot.hasExactTitle && !snapshots[duplicateIndex].hasExactTitle {
                    snapshots[duplicateIndex] = snapshot
                }

                continue
            }

            snapshots.append(snapshot)
        }

        return snapshots
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private static func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 12) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) <= tolerance &&
            abs(lhs.origin.y - rhs.origin.y) <= tolerance &&
            abs(lhs.size.width - rhs.size.width) <= tolerance &&
            abs(lhs.size.height - rhs.size.height) <= tolerance
    }
}
