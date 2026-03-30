import CoreGraphics
import Foundation

public struct WindowSnapshot: Equatable, Sendable {
    public let windowID: CGWindowID
    public let pid: pid_t
    public let appName: String
    public let title: String
    public let bounds: CGRect

    public init(windowID: CGWindowID, pid: pid_t, appName: String, title: String, bounds: CGRect) {
        self.windowID = windowID
        self.pid = pid
        self.appName = appName
        self.title = title
        self.bounds = bounds
    }
}

public struct WindowRecord: Sendable {
    public let windowID: CGWindowID?
    public let ownerPID: pid_t?
    public let ownerName: String?
    public let title: String?
    public let layer: Int?
    public let alpha: Double?
    public let bounds: CGRect?
    public let isOnscreen: Bool?

    public init(
        windowID: CGWindowID?,
        ownerPID: pid_t?,
        ownerName: String?,
        title: String?,
        layer: Int?,
        alpha: Double?,
        bounds: CGRect?,
        isOnscreen: Bool?
    ) {
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.title = title
        self.layer = layer
        self.alpha = alpha
        self.bounds = bounds
        self.isOnscreen = isOnscreen
    }
}
