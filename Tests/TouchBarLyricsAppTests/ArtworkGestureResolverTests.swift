import AppKit
import CoreGraphics
import Testing
@testable import TouchBarLyricsApp

@Suite("Artwork gestures")
struct ArtworkGestureResolverTests {
    @MainActor
    @Test("The full Touch Bar area accepts direct two-finger pinch input")
    func directPinchConfiguration() {
        let container = TouchBarFocusGestureView(
            frame: NSRect(x: 0, y: 0, width: 720, height: 30)
        )
        let recognizers = container.gestureRecognizers.compactMap {
            $0 as? NSMagnificationGestureRecognizer
        }

        #expect(container.bounds.width == 720)
        #expect(recognizers.count == 1)
        #expect(recognizers.first?.allowedTouchTypes == .direct)
    }

    @Test("A left swipe selects the next track")
    func leftSwipe() {
        let command = ArtworkGestureResolver.command(
            translation: CGPoint(x: -44, y: 2),
            velocity: .zero
        )
        #expect(command == .next)
    }

    @Test("A right swipe selects the previous track")
    func rightSwipe() {
        let command = ArtworkGestureResolver.command(
            translation: CGPoint(x: 44, y: -2),
            velocity: .zero
        )
        #expect(command == .previous)
    }

    @Test("Visual movement is direct, then resisted, and finally capped")
    func elasticVisualOffset() {
        #expect(ArtworkGestureResolver.visualOffset(for: 20) == 20)
        #expect(ArtworkGestureResolver.visualOffset(for: -40) == -40)
        #expect(ArtworkGestureResolver.visualOffset(for: 60) == 47)
        #expect(ArtworkGestureResolver.visualOffset(for: -60) == -47)
        #expect(ArtworkGestureResolver.visualOffset(for: 200) == 65)
        #expect(ArtworkGestureResolver.visualOffset(for: -200) == -65)
    }

    @Test("A fast short swipe is accepted")
    func fastSwipe() {
        let command = ArtworkGestureResolver.command(
            translation: CGPoint(x: -8, y: 1),
            velocity: CGPoint(x: -400, y: 0)
        )
        #expect(command == .next)
    }

    @Test("Short and vertical gestures do not change tracks")
    func rejectedGestures() {
        #expect(
            ArtworkGestureResolver.command(
                translation: CGPoint(x: 8, y: 1),
                velocity: .zero
            ) == nil
        )
        #expect(
            ArtworkGestureResolver.command(
                translation: CGPoint(x: 10, y: 20),
                velocity: CGPoint(x: 400, y: 0)
            ) == nil
        )
    }

    @Test("An outward pinch enters artwork focus mode")
    func outwardPinch() {
        #expect(
            ArtworkFocusGestureResolver.shouldToggle(
                magnification: 0.1,
                focused: false
            )
        )
        #expect(
            !ArtworkFocusGestureResolver.shouldToggle(
                magnification: 0.1,
                focused: true
            )
        )
    }

    @Test("An inward pinch exits artwork focus mode")
    func inwardPinch() {
        #expect(
            ArtworkFocusGestureResolver.shouldToggle(
                magnification: -0.1,
                focused: true
            )
        )
        #expect(
            !ArtworkFocusGestureResolver.shouldToggle(
                magnification: -0.1,
                focused: false
            )
        )
    }

    @Test("Small pinches are ignored")
    func smallPinches() {
        #expect(
            !ArtworkFocusGestureResolver.shouldToggle(
                magnification: 0.04,
                focused: false
            )
        )
        #expect(
            !ArtworkFocusGestureResolver.shouldToggle(
                magnification: -0.04,
                focused: true
            )
        )
    }
}
