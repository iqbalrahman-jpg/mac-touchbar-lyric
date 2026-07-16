@preconcurrency import AppKit

@MainActor
final class TouchBarFocusGestureView: NSView {
    var onMagnification: ((CGFloat) -> Bool)?

    private var hasHandledCurrentPinch = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureMagnificationGesture()
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc private func magnified(_ recognizer: NSMagnificationGestureRecognizer) {
        switch recognizer.state {
        case .began:
            hasHandledCurrentPinch = false

        case .changed, .ended:
            if !hasHandledCurrentPinch,
               onMagnification?(recognizer.magnification) == true {
                hasHandledCurrentPinch = true
            }
            if recognizer.state == .ended {
                hasHandledCurrentPinch = false
            }

        case .cancelled, .failed:
            hasHandledCurrentPinch = false

        default:
            break
        }
    }

    private func configureMagnificationGesture() {
        let magnification = NSMagnificationGestureRecognizer(
            target: self,
            action: #selector(magnified)
        )
        allowedTouchTypes = .direct
        magnification.allowedTouchTypes = .direct
        addGestureRecognizer(magnification)
    }
}
