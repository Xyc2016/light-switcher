import AppKit
import Foundation

public final class SwitcherPanelController: NSWindowController {
    private let iconCache: AppIconCache
    private let stackView = NSStackView()
    private let containerView = NSView()
    private var rowViews: [WindowRowView] = []
    private var snapshots: [WindowSnapshot] = []
    private var currentSelection = 0

    public init(iconCache: AppIconCache) {
        self.iconCache = iconCache

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 220),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.96)
        panel.hasShadow = true
        panel.collectionBehavior = [.transient, .ignoresCycle, .moveToActiveSpace]
        panel.isOpaque = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true

        super.init(window: panel)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    public var isVisible: Bool {
        window?.isVisible == true
    }

    public func show(windows: [WindowSnapshot], selectedIndex: Int) {
        snapshots = windows
        currentSelection = selectedIndex
        rebuildRows()
        resizeWindow()
        centerWindow()
        window?.orderFrontRegardless()
    }

    public func updateSelection(_ selectedIndex: Int) {
        currentSelection = selectedIndex
        for (index, rowView) in rowViews.enumerated() {
            rowView.isHighlighted = index == selectedIndex
        }
    }

    public func dismiss() {
        snapshots = []
        rowViews.removeAll()
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        close()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else {
            return
        }

        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 16
        containerView.layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.96).cgColor

        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        contentView.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }

    private func rebuildRows() {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        rowViews = snapshots.enumerated().map { index, snapshot in
            let row = WindowRowView(frame: .zero)
            row.translatesAutoresizingMaskIntoConstraints = false
            row.heightAnchor.constraint(equalToConstant: 34).isActive = true
            row.configure(
                icon: iconCache.icon(for: snapshot.pid),
                title: snapshot.title,
                subtitle: snapshot.appName
            )
            row.isHighlighted = index == currentSelection
            stackView.addArrangedSubview(row)
            return row
        }
    }

    private func resizeWindow() {
        guard let window else {
            return
        }

        let visibleRows = max(1, min(snapshots.count, 8))
        let height = CGFloat(visibleRows * 42) + 28
        let width = max(380, min(640, snapshots.map { CGFloat($0.title.count) * 7 + 160 }.max() ?? 420))
        window.setContentSize(NSSize(width: width, height: height))
    }

    private func centerWindow() {
        guard let window, let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.midX - (window.frame.width / 2),
            y: frame.midY - (window.frame.height / 2)
        )
        window.setFrameOrigin(origin)
    }
}

private final class WindowRowView: NSView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")

    var isHighlighted: Bool = false {
        didSet {
            needsDisplay = true
            titleLabel.textColor = isHighlighted ? .white : NSColor(calibratedWhite: 0.95, alpha: 1)
            subtitleLabel.textColor = isHighlighted ? NSColor.white.withAlphaComponent(0.82) : NSColor(calibratedWhite: 0.75, alpha: 1)
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(icon: NSImage, title: String, subtitle: String) {
        iconView.image = icon
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted {
            NSColor.systemBlue.withAlphaComponent(0.88).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10).fill()
        }
    }

    private func setup() {
        wantsLayer = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.lineBreakMode = .byTruncatingTail

        let textStack = NSStackView(views: [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}
