import AppKit
import CoreGraphics
import Testing
@testable import TouchBarLyricsApp

@Suite("Artwork gestures")
struct ArtworkGestureResolverTests {
    @MainActor
    @Test("The artwork group recognizes direct single and double taps")
    func tapConfiguration() {
        let control = AlbumArtworkControl(frame: .zero)
        let recognizers = control.gestureRecognizers.compactMap {
            $0 as? NSClickGestureRecognizer
        }.sorted { $0.numberOfClicksRequired < $1.numberOfClicksRequired }

        #expect(recognizers.count == 2)
        #expect(recognizers.map(\.numberOfClicksRequired) == [1, 2])
        #expect(recognizers.allSatisfy { $0.numberOfTouchesRequired == 1 })
        #expect(recognizers.allSatisfy { $0.allowedTouchTypes == .direct })
        #expect(
            control.gestureRecognizer(
                recognizers[0],
                shouldRequireFailureOf: recognizers[1]
            )
        )
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

}
