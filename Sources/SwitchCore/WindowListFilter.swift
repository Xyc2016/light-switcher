import CoreGraphics
import Foundation

public enum WindowListFilter {
    public static func filter(records: [WindowRecord], excludingPID: pid_t) -> [WindowSnapshot] {
        var seen = Set<CGWindowID>()

        return records.compactMap { record in
            guard
                let windowID = record.windowID,
                let pid = record.ownerPID,
                let appName = trimmed(record.ownerName),
                let title = trimmed(record.title),
                let bounds = record.bounds
            else {
                return nil
            }

            guard pid != excludingPID else {
                return nil
            }

            guard record.layer == 0 else {
                return nil
            }

            if let isOnscreen = record.isOnscreen, !isOnscreen {
                return nil
            }

            if let alpha = record.alpha, alpha <= 0 {
                return nil
            }

            guard bounds.width > 1, bounds.height > 1 else {
                return nil
            }

            guard seen.insert(windowID).inserted else {
                return nil
            }

            return WindowSnapshot(
                windowID: windowID,
                pid: pid,
                appName: appName,
                title: title,
                bounds: bounds
            )
        }
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
