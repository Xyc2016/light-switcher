import AppKit
#if canImport(SwitchCore)
import SwitchCore
#endif

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let permissionsService = PermissionsService()
    private let iconCache = AppIconCache()
    private lazy var panelController = SwitcherPanelController(iconCache: iconCache)
    private lazy var switchService = WindowSwitchService(permissionsService: permissionsService)
    private lazy var windowQueryService: any WindowQuerying = WindowQueryService(
        titleResolver: WindowTitleResolver(permissionsService: permissionsService)
    )
    private let hotkeyService = HotkeyService()

    private var statusItem: NSStatusItem?
    private var activeSnapshots: [WindowSnapshot] = []
    private var selectedIndex = 0
    private var isCycling = false
    private var isPresentingAccessibilityPrompt = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupHotkeyCallbacks()
        hotkeyService.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyService.unregister()
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }

    @objc
    private func openAccessibilitySettings() {
        permissionsService.openAccessibilitySettings()
    }

    private func setupHotkeyCallbacks() {
        hotkeyService.onHotkeyPressed = { [weak self] in
            self?.handleHotkeyPress()
        }
        hotkeyService.onModifierReleased = { [weak self] in
            self?.finishCycle()
        }
    }

    private func handleHotkeyPress() {
        guard permissionsService.isAccessibilityTrusted(prompt: false) else {
            promptForAccessibility()
            return
        }

        if isCycling {
            guard !activeSnapshots.isEmpty else {
                return
            }

            selectedIndex = (selectedIndex + 1) % activeSnapshots.count
            panelController.updateSelection(selectedIndex)
            return
        }

        let snapshots = windowQueryService.snapshotVisibleWindows(excludingPID: getpid())
        guard snapshots.count > 1 else {
            return
        }

        activeSnapshots = snapshots
        selectedIndex = min(1, snapshots.count - 1)
        isCycling = true
        panelController.show(windows: snapshots, selectedIndex: selectedIndex)
        hotkeyService.startReleaseMonitoring()
    }

    private func finishCycle() {
        defer {
            activeSnapshots = []
            selectedIndex = 0
            isCycling = false
            panelController.dismiss()
        }

        guard activeSnapshots.indices.contains(selectedIndex) else {
            return
        }

        switchService.activate(activeSnapshots[selectedIndex])
    }

    private func promptForAccessibility() {
        guard !isPresentingAccessibilityPrompt else {
            return
        }

        isPresentingAccessibilityPrompt = true
        _ = permissionsService.isAccessibilityTrusted(prompt: true)

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = "LightSwitcher needs Accessibility access to list and focus windows."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            permissionsService.openAccessibilitySettings()
        }

        isPresentingAccessibilityPrompt = false
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "LightSwitcher")
        statusItem.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit LightSwitcher", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }

        statusItem.menu = menu
        self.statusItem = statusItem
    }
}
