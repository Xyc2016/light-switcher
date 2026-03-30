import ApplicationServices
import CoreGraphics
import Foundation

public protocol WindowTitleResolving: Sendable {
    func enrichTitles(in snapshots: [WindowSnapshot]) -> [WindowSnapshot]
}

public final class WindowTitleResolver: WindowTitleResolving, @unchecked Sendable {
    private let permissionsService: PermissionsService

    public init(permissionsService: PermissionsService) {
        self.permissionsService = permissionsService
    }

    public func enrichTitles(in snapshots: [WindowSnapshot]) -> [WindowSnapshot] {
        guard permissionsService.isAccessibilityTrusted(prompt: false) else {
            return snapshots
        }

        let missingTitleIndices = snapshots.indices.filter { !snapshots[$0].hasExactTitle }
        guard !missingTitleIndices.isEmpty else {
            return snapshots
        }

        var enrichedSnapshots = snapshots
        let indicesByPID = Dictionary(grouping: missingTitleIndices, by: { snapshots[$0].pid })

        for (pid, indices) in indicesByPID {
            let candidates = fetchCandidates(for: pid)
            guard !candidates.isEmpty else {
                continue
            }

            for index in indices {
                let snapshot = enrichedSnapshots[index]
                guard let resolvedTitle = bestTitle(for: snapshot, candidates: candidates) else {
                    continue
                }

                enrichedSnapshots[index] = snapshot.withResolvedTitle(resolvedTitle)
            }
        }

        return enrichedSnapshots
    }

    private func fetchCandidates(for pid: pid_t) -> [WindowCandidate] {
        let appElement = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let windows = value as? [AXUIElement] else {
            return []
        }

        return windows.compactMap(makeCandidate)
    }

    private func makeCandidate(window: AXUIElement) -> WindowCandidate? {
        guard !isMinimized(window) else {
            return nil
        }

        guard let title = trimmed(copyString(window, attribute: kAXTitleAttribute)) else {
            return nil
        }

        return WindowCandidate(title: title, frame: copyFrame(window))
    }

    private func bestTitle(for snapshot: WindowSnapshot, candidates: [WindowCandidate]) -> String? {
        let bestCandidate = candidates
            .map { candidate in (candidate, score(candidate: candidate, snapshot: snapshot)) }
            .max { $0.1 < $1.1 }

        if let bestCandidate, bestCandidate.1 > 0 {
            return bestCandidate.0.title
        }

        if candidates.count == 1 {
            return candidates[0].title
        }

        return nil
    }

    private func score(candidate: WindowCandidate, snapshot: WindowSnapshot) -> Int {
        guard let frame = candidate.frame else {
            return 0
        }

        var score = 0

        if approximatelyEqual(frame.origin.x, snapshot.bounds.origin.x) &&
            approximatelyEqual(frame.origin.y, snapshot.bounds.origin.y)
        {
            score += 60
        }

        if approximatelyEqual(frame.size.width, snapshot.bounds.size.width) &&
            approximatelyEqual(frame.size.height, snapshot.bounds.size.height)
        {
            score += 50
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
        guard result == .success, let value else {
            return nil
        }

        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == type else {
            return nil
        }

        return axValue
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func approximatelyEqual(_ lhs: CGFloat, _ rhs: CGFloat, tolerance: CGFloat = 10) -> Bool {
        abs(lhs - rhs) <= tolerance
    }
}

private struct WindowCandidate {
    let title: String
    let frame: CGRect?
}
