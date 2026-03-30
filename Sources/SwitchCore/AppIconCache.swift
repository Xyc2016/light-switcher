import AppKit
import Foundation
import UniformTypeIdentifiers

public final class AppIconCache: @unchecked Sendable {
    private let cache = NSCache<NSNumber, NSImage>()

    public init(limit: Int = 32) {
        cache.countLimit = limit
    }

    public func icon(for pid: pid_t) -> NSImage {
        let key = NSNumber(value: pid)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let icon = NSRunningApplication(processIdentifier: pid)?.icon
            ?? NSWorkspace.shared.icon(forContentType: .applicationBundle)
        icon.size = NSSize(width: 18, height: 18)
        cache.setObject(icon, forKey: key)
        return icon
    }
}
