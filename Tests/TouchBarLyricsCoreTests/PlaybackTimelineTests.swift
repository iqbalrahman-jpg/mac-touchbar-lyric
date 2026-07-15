import Testing
@testable import TouchBarLyricsCore

@Suite("Playback timeline")
struct PlaybackTimelineTests {
    @Test("Advances while playing")
    func advancesWhilePlaying() {
        let timeline = PlaybackTimeline(position: 10, state: .playing, uptime: 100)
        #expect(timeline.position(at: 101.25) == 11.25)
    }

    @Test("Stays fixed while paused")
    func staysFixedWhilePaused() {
        let timeline = PlaybackTimeline(position: 10, state: .paused, uptime: 100)
        #expect(timeline.position(at: 150) == 10)
    }

    @Test("Does not move backward for an older uptime")
    func clampsClockMovement() {
        let timeline = PlaybackTimeline(position: 10, state: .playing, uptime: 100)
        #expect(timeline.position(at: 99) == 10)
    }
}
