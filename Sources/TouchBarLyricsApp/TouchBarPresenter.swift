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
    var onRevealRequested: (() -> Void)?
    var onPlaybackCommandRequested: ((SpotifyPlaybackCommand) -> Void)?

    private let artworkControl = AlbumArtworkControl()
    private let textView = KaraokeTextView()
    private let container = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 30))
    private let touchBar = NSTouchBar()
    private var controlStripItem: NSCustomTouchBarItem?
    private var presentationState = TouchBarPresentationState()
    private var visibilityMonitor: Timer?
    private var workspaceObserver: NSObjectProtocol?
    private var ignoreHiddenUntil: TimeInterval = 0

    override init() {
        super.init()
        configureContent()
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

    var textColor: NSColor {
        textView.textColor
    }

    func setTextColor(_ color: NSColor) {
        textView.textColor = color
    }

    func setArtwork(_ image: NSImage?) {
        artworkControl.setArtwork(image)
    }

    func setArtworkInteractionEnabled(_ enabled: Bool) {
        artworkControl.setEnabled(enabled)
    }

    func setTrackTitle(_ title: String?) {
        artworkControl.setTrackTitle(title)
    }

    func show(text: String, progress: Double? = nil, dimmed: Bool) {
        fitFont(to: text)
        textView.update(text: text, progress: progress, dimmed: dimmed)
        if presentationState.showContent() {
            present()
        }
        startVisibilityMonitor()
    }

    func dismiss() {
        presentationState.hideContent()
        stopVisibilityMonitor()
        TBLDismissTouchBar(touchBar)
    }

    func reveal() {
        if presentationState.reveal() {
            present()
            startVisibilityMonitor()
        }
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
        onRevealRequested?()
    }

    private func configureContent() {
        artworkControl.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        artworkControl.onCommandRequested = { [weak self] command in
            self?.onPlaybackCommandRequested?(command)
        }
        container.addSubview(artworkControl)
        container.addSubview(textView)
        NSLayoutConstraint.activate([
            artworkControl.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            artworkControl.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            textView.leadingAnchor.constraint(equalTo: artworkControl.trailingAnchor, constant: 8),
            textView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            textView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            textView.heightAnchor.constraint(equalToConstant: 30),
            container.widthAnchor.constraint(equalToConstant: 720),
            container.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    private func fitFont(to text: String) {
        let maximumSize: CGFloat = 15
        let minimumSize: CGFloat = 10
        container.layoutSubtreeIfNeeded()
        let availableWidth = max(1, textView.bounds.width)
        let baseFont = NSFont.systemFont(ofSize: maximumSize, weight: .medium)
        let measuredWidth = (text as NSString).size(withAttributes: [.font: baseFont]).width
        let fittedSize: CGFloat
        if measuredWidth > availableWidth {
            fittedSize = max(minimumSize, maximumSize * availableWidth / measuredWidth)
        } else {
            fittedSize = maximumSize
        }
        textView.font = .systemFont(ofSize: fittedSize, weight: .medium)
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
                guard let self, self.presentationState.shouldRestoreAfterAppSwitch else {
                    return
                }
                self.ignoreHiddenUntil = ProcessInfo.processInfo.systemUptime + 0.5
                try? await Task.sleep(for: .milliseconds(150))
                guard self.presentationState.shouldRestoreAfterAppSwitch else { return }
                self.present()
            }
        }
    }

    private func present() {
        guard presentationState.shouldRestoreAfterAppSwitch, privateAPIAvailable else {
            return
        }
        _ = TBLPresentTouchBar(touchBar, .controlStripItem)
    }

    private func startVisibilityMonitor() {
        guard visibilityMonitor == nil else { return }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let isTemporaryHide = ProcessInfo.processInfo.systemUptime
                    < self.ignoreHiddenUntil
                self.presentationState.observeVisibility(
                    self.touchBar.isVisible,
                    temporaryHide: isTemporaryHide
                )
            }
        }
        timer.tolerance = 0.02
        RunLoop.main.add(timer, forMode: .common)
        visibilityMonitor = timer
    }

    private func stopVisibilityMonitor() {
        visibilityMonitor?.invalidate()
        visibilityMonitor = nil
    }
}
