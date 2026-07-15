@preconcurrency import AppKit
import Foundation
import TouchBarPrivateBridge

private extension NSTouchBarItem.Identifier {
    static let lyrics = NSTouchBarItem.Identifier("com.iqbalrahman.TouchBarLyrics.lyrics")
    static let controlStripItem = NSTouchBarItem.Identifier(
        "com.iqbalrahman.TouchBarLyrics.controlStrip"
    )
}

@MainActor
final class TouchBarPresenter: NSObject, NSTouchBarDelegate {
    var onToggleRequested: (() -> Void)?

    private let label = NSTextField(labelWithString: "")
    private let container = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 30))
    private let touchBar = NSTouchBar()
    private var controlStripItem: NSCustomTouchBarItem?
    private var shouldBeVisible = false
    private var watchdog: Timer?
    private var workspaceObserver: NSObjectProtocol?

    override init() {
        super.init()
        configureLabel()
        configureTouchBar()
        installControlStripItem()
        observeAppChanges()
    }

    deinit {
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
    }

    var privateAPIAvailable: Bool {
        TBLPrivateTouchBarAPIAvailable()
    }

    func show(text: String, dimmed: Bool) {
        label.stringValue = text
        fitFont(to: text)
        label.alphaValue = dimmed ? 0.55 : 1
        shouldBeVisible = true
        present()
        startWatchdog()
    }

    func dismiss() {
        shouldBeVisible = false
        stopWatchdog()
        TBLDismissTouchBar(touchBar)
    }

    func tearDown() {
        dismiss()
        if let controlStripItem {
            TBLRemoveSystemTrayItem(controlStripItem, .controlStripItem)
        }
        controlStripItem = nil
    }

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        guard identifier == .lyrics else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        item.customizationLabel = "Spotify Lyrics"
        item.visibilityPriority = .high
        item.view = container
        return item
    }

    @objc private func controlStripTapped() {
        onToggleRequested?()
    }

    private func configureLabel() {
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .left
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.usesSingleLineMode = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: 720),
            container.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    private func fitFont(to text: String) {
        let maximumSize: CGFloat = 15
        let minimumSize: CGFloat = 10
        let availableWidth: CGFloat = 696
        let baseFont = NSFont.systemFont(ofSize: maximumSize, weight: .medium)
        let measuredWidth = (text as NSString).size(withAttributes: [.font: baseFont]).width
        let fittedSize: CGFloat
        if measuredWidth > availableWidth {
            fittedSize = max(minimumSize, maximumSize * availableWidth / measuredWidth)
        } else {
            fittedSize = maximumSize
        }
        label.font = .systemFont(ofSize: fittedSize, weight: .medium)
    }

    private func configureTouchBar() {
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [.lyrics]
        touchBar.principalItemIdentifier = .lyrics
    }

    private func installControlStripItem() {
        guard privateAPIAvailable else { return }

        let item = NSCustomTouchBarItem(identifier: .controlStripItem)
        let image = NSImage(
            systemSymbolName: "quote.bubble",
            accessibilityDescription: "Spotify lyrics"
        )
        let button: NSButton
        if let image {
            button = NSButton(image: image, target: self, action: #selector(controlStripTapped))
        } else {
            button = NSButton(title: "♫", target: self, action: #selector(controlStripTapped))
        }
        item.view = button
        if TBLInstallSystemTrayItem(item, .controlStripItem) {
            controlStripItem = item
        }
    }

    private func observeAppChanges() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.shouldBeVisible else { return }
                try? await Task.sleep(for: .milliseconds(150))
                self.present()
            }
        }
    }

    private func present() {
        guard shouldBeVisible, privateAPIAvailable else { return }
        _ = TBLPresentTouchBar(touchBar, .controlStripItem)
    }

    private func startWatchdog() {
        guard watchdog == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.shouldBeVisible, !self.touchBar.isVisible else { return }
                self.present()
            }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        watchdog = timer
    }

    private func stopWatchdog() {
        watchdog?.invalidate()
        watchdog = nil
    }
}
