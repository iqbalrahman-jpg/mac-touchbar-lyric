@preconcurrency import AppKit

@MainActor
final class KaraokeTextView: NSView {
    var textColor = NSColor.labelColor {
        didSet { needsDisplay = true }
    }

    var font = NSFont.systemFont(ofSize: 14, weight: .medium) {
        didSet { needsDisplay = true }
    }

    private var text = ""
    private var progress: CGFloat?
    private var isDimmed = false

    override var isFlipped: Bool { true }

    func update(text: String, progress: Double?, dimmed: Bool) {
        self.text = text
        self.progress = progress.map { CGFloat(max(0, min(1, $0))) }
        isDimmed = dimmed
        setAccessibilityLabel(text)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !text.isEmpty else { return }

        let opacity: CGFloat = isDimmed ? 0.55 : 1
        let activeColor = textColor.withAlphaComponent(textColor.alphaComponent * opacity)
        let upcomingColor = activeColor.withAlphaComponent(activeColor.alphaComponent * 0.3)
        let activeText = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: activeColor
            ]
        )
        let size = activeText.size()
        let origin = NSPoint(x: 0, y: max(0, (bounds.height - size.height) / 2))

        guard let progress else {
            activeText.draw(at: origin)
            return
        }

        NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: upcomingColor
            ]
        ).draw(at: origin)

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(
            rect: NSRect(
                x: 0,
                y: 0,
                width: size.width * progress,
                height: bounds.height
            )
        ).addClip()
        activeText.draw(at: origin)
        NSGraphicsContext.restoreGraphicsState()
    }
}
