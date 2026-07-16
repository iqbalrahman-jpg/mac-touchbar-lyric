@preconcurrency import AppKit
import QuartzCore

enum ArtworkGestureResolver {
    static let distanceThreshold: CGFloat = 36
    static let velocityThreshold: CGFloat = 250
    static let freeMovement: CGFloat = 40
    static let resistance: CGFloat = 0.35
    static let maximumVisualOffset: CGFloat = 65

    static func visualOffset(for translationX: CGFloat) -> CGFloat {
        let direction: CGFloat = translationX < 0 ? -1 : 1
        let distance = abs(translationX)
        guard distance > freeMovement else { return translationX }

        let resistedDistance = freeMovement + (distance - freeMovement) * resistance
        return direction * min(maximumVisualOffset, resistedDistance)
    }

    static func command(
        translation: CGPoint,
        velocity: CGPoint
    ) -> SpotifyPlaybackCommand? {
        guard abs(translation.x) > abs(translation.y) * 1.25,
              abs(translation.x) >= distanceThreshold
                || abs(velocity.x) >= velocityThreshold else {
            return nil
        }
        return translation.x < 0 ? .next : .previous
    }
}

@MainActor
final class AlbumArtworkControl: NSView, NSGestureRecognizerDelegate {
    var onCommandRequested: ((SpotifyPlaybackCommand) -> Void)?
    var onFocusToggleRequested: (() -> Void)?

    private let imageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "Spotify")
    private var imageLeadingConstraint: NSLayoutConstraint!
    private var singleClickRecognizer: NSClickGestureRecognizer!
    private var doubleClickRecognizer: NSClickGestureRecognizer!
    private var pendingSingleTapTimer: Timer?
    private var currentVisualOffset: CGFloat = 0
    private(set) var isEnabled = false {
        didSet { alphaValue = isEnabled ? 1 : 0.4 }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureContent()
        configureGestures()
        setAccessibilityRole(.button)
        setAccessibilityLabel("Spotify album artwork")
        updateAccessibilityHelp(focused: false)
        showPlaceholder()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    func setArtwork(_ image: NSImage?) {
        if let image {
            imageView.image = image
        } else {
            showPlaceholder()
        }
    }

    func setTrackTitle(_ title: String?) {
        let title = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = title.flatMap { $0.isEmpty ? nil : $0 } ?? "Spotify"
        titleLabel.stringValue = displayTitle
        titleLabel.toolTip = displayTitle
        setAccessibilityLabel("Spotify: \(displayTitle)")
    }

    func setFocusMode(_ focused: Bool) {
        resetTranslation()
        updateAccessibilityHelp(focused: focused)
    }

    @objc private func tapped() {
        guard isEnabled else { return }
        pendingSingleTapTimer?.invalidate()
        let singleTapDelay = NSEvent.doubleClickInterval + 0.05
        let timer = Timer(timeInterval: singleTapDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.pendingSingleTapTimer = nil
                self.onCommandRequested?(.playPause)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pendingSingleTapTimer = timer
    }

    @objc private func doubleTapped() {
        pendingSingleTapTimer?.invalidate()
        pendingSingleTapTimer = nil
        onFocusToggleRequested?()
    }

    @objc private func panned(_ recognizer: NSPanGestureRecognizer) {
        guard isEnabled else {
            resetTranslation()
            return
        }

        let translation = recognizer.translation(in: self)
        switch recognizer.state {
        case .began, .changed:
            applyTranslation(ArtworkGestureResolver.visualOffset(for: translation.x))

        case .ended:
            let velocity = recognizer.velocity(in: self)
            let command = ArtworkGestureResolver.command(
                translation: translation,
                velocity: velocity
            )
            resetTranslation()
            if let command {
                onCommandRequested?(command)
            }

        case .cancelled, .failed:
            resetTranslation()

        default:
            break
        }
    }

    private func configureContent() {
        wantsLayer = true
        layer?.masksToBounds = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 5
        imageView.layer?.masksToBounds = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.wantsLayer = true
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.usesSingleLineMode = true
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(imageView)
        addSubview(titleLabel)

        imageLeadingConstraint = imageView.leadingAnchor.constraint(
            equalTo: leadingAnchor,
            constant: 9
        )

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 164),
            heightAnchor.constraint(equalToConstant: 30),
            imageView.widthAnchor.constraint(equalToConstant: 28),
            imageView.heightAnchor.constraint(equalToConstant: 28),
            imageLeadingConstraint,
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 46),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func configureGestures() {
        let singleClick = NSClickGestureRecognizer(target: self, action: #selector(tapped))
        let doubleClick = NSClickGestureRecognizer(
            target: self,
            action: #selector(doubleTapped)
        )
        let pan = NSPanGestureRecognizer(target: self, action: #selector(panned))
        allowedTouchTypes = .direct
        singleClick.allowedTouchTypes = .direct
        singleClick.numberOfTouchesRequired = 1
        singleClick.numberOfClicksRequired = 1
        singleClick.delegate = self
        doubleClick.allowedTouchTypes = .direct
        doubleClick.numberOfTouchesRequired = 1
        doubleClick.numberOfClicksRequired = 2
        doubleClick.delegate = self
        pan.allowedTouchTypes = .direct
        pan.numberOfTouchesRequired = 1
        singleClickRecognizer = singleClick
        doubleClickRecognizer = doubleClick
        addGestureRecognizer(singleClick)
        addGestureRecognizer(doubleClick)
        addGestureRecognizer(pan)
    }

    func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer
    ) -> Bool {
        let isClickPair = gestureRecognizer === singleClickRecognizer
            && otherGestureRecognizer === doubleClickRecognizer
        let isReverseClickPair = gestureRecognizer === doubleClickRecognizer
            && otherGestureRecognizer === singleClickRecognizer
        return isClickPair || isReverseClickPair
    }

    private func resetTranslation() {
        let offset = currentVisualOffset
        currentVisualOffset = 0
        let spring = CASpringAnimation(keyPath: "transform.translation.x")
        spring.fromValue = offset
        spring.toValue = 0
        spring.mass = 1
        spring.stiffness = 260
        spring.damping = 22
        spring.initialVelocity = 0
        spring.duration = spring.settlingDuration

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in contentLayers {
            layer.transform = CATransform3DIdentity
            layer.opacity = 1
            layer.add(spring, forKey: "swipeReturn")
        }
        CATransaction.commit()
    }

    private var contentLayers: [CALayer] {
        [imageView.layer, titleLabel.layer].compactMap { $0 }
    }

    private func applyTranslation(_ offset: CGFloat) {
        currentVisualOffset = offset
        let progress = min(1, abs(offset) / ArtworkGestureResolver.maximumVisualOffset)
        let opacity = Float(1 - progress * 0.25)
        let transform = CATransform3DMakeTranslation(offset, 0, 0)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in contentLayers {
            layer.removeAnimation(forKey: "swipeReturn")
            layer.transform = transform
            layer.opacity = opacity
        }
        CATransaction.commit()
    }

    private func showPlaceholder() {
        if let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.spotify.client"
        ) {
            imageView.image = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            imageView.image = NSImage(
                systemSymbolName: "music.note",
                accessibilityDescription: "Spotify"
            )
        }
    }

    private func updateAccessibilityHelp(focused: Bool) {
        if focused {
            setAccessibilityHelp(
                "Tap to play or pause. Double tap to show lyrics. "
                    + "Swipe left or right to change tracks."
            )
        } else {
            setAccessibilityHelp(
                "Tap to play or pause. Double tap to focus the album cover and title. "
                    + "Swipe left or right to change tracks."
            )
        }
    }
}
