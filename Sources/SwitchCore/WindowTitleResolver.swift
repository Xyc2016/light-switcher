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

            let assignments = resolveTitles(
                for: indices.map { enrichedSnapshots[$0] },
                candidates: candidates
            )

            for (snapshotIndex, resolvedTitle) in assignments {
                let originalIndex = indices[snapshotIndex]
                enrichedSnapshots[originalIndex] = enrichedSnapshots[originalIndex].withResolvedTitle(resolvedTitle)
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

    private func resolveTitles(
        for snapshots: [WindowSnapshot],
        candidates: [WindowCandidate]
    ) -> [Int: String] {
        if snapshots.count == 1, candidates.count == 1 {
            return [0: candidates[0].title]
        }

        let matches = snapshots.enumerated().flatMap { snapshotEntry -> [TitleMatch] in
            let (snapshotIndex, snapshot) = snapshotEntry

            return candidates.enumerated().compactMap { candidateEntry -> TitleMatch? in
                let (candidateIndex, candidate) = candidateEntry
                let matchScore = score(candidate: candidate, snapshot: snapshot)
                guard matchScore > 0 else {
                    return nil
                }

                return TitleMatch(
                    snapshotIndex: snapshotIndex,
                    candidateIndex: candidateIndex,
                    score: matchScore
                )
            }
        }
        .sorted {
            if $0.score != $1.score {
                return $0.score > $1.score
            }

            if $0.snapshotIndex != $1.snapshotIndex {
                return $0.snapshotIndex < $1.snapshotIndex
            }

            return $0.candidateIndex < $1.candidateIndex
        }

        var assignedSnapshots = Set<Int>()
        var usedCandidates = Set<Int>()
        var resolvedTitles: [Int: String] = [:]

        for match in matches {
            guard
                assignedSnapshots.insert(match.snapshotIndex).inserted,
                usedCandidates.insert(match.candidateIndex).inserted
            else {
                continue
            }

            resolvedTitles[match.snapshotIndex] = candidates[match.candidateIndex].title
        }

        return resolvedTitles
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

private struct TitleMatch {
    let snapshotIndex: Int
    let candidateIndex: Int
    let score: Int
}
