import AppKit

let currentPID = ProcessInfo.processInfo.processIdentifier
if let bundleIdentifier = Bundle.main.bundleIdentifier {
    let isAnotherInstanceRunning = NSRunningApplication
        .runningApplications(withBundleIdentifier: bundleIdentifier)
        .contains { $0.processIdentifier != currentPID }

    if isAnotherInstanceRunning {
        exit(0)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
