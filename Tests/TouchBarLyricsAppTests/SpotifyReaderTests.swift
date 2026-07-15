import AppKit
import Testing
import TouchBarLyricsCore
@testable import TouchBarLyricsApp

@Suite("Spotify Apple Event decoding")
struct SpotifyReaderTests {
    @Test("Decodes typed timing values without locale-sensitive strings")
    func decodesTypedResponse() throws {
        let descriptor = NSAppleEventDescriptor.list()
        descriptor.insert(.init(string: "spotify:track:test"), at: 1)
        descriptor.insert(.init(string: "Great Expectation"), at: 2)
        descriptor.insert(.init(string: "SIENNA SPIRO"), at: 3)
        descriptor.insert(.init(string: "Visitor"), at: 4)
        descriptor.insert(.init(int32: 173_975), at: 5)
        descriptor.insert(.init(double: 60.681_999), at: 6)
        descriptor.insert(.init(string: "paused"), at: 7)

        let snapshot = try SpotifyReader.decode(descriptor).get()

        #expect(snapshot.track?.id == "spotify:track:test")
        #expect(snapshot.track?.duration == 173.975)
        #expect(snapshot.position == 60.681_999)
        #expect(snapshot.state == .paused)
    }

    @Test("Recognizes the typed stopped response")
    func decodesStoppedResponse() throws {
        let descriptor = NSAppleEventDescriptor.list()
        descriptor.insert(.init(string: "stopped"), at: 1)

        #expect(try SpotifyReader.decode(descriptor).get() == .stopped)
    }

    @Test("Reports the actual field count")
    func rejectsUnexpectedFieldCount() {
        let descriptor = NSAppleEventDescriptor.list()
        descriptor.insert(.init(string: "playing"), at: 1)
        descriptor.insert(.init(string: "extra"), at: 2)

        switch SpotifyReader.decode(descriptor) {
        case .success:
            Issue.record("Expected malformed response to fail")
        case .failure(let error):
            #expect(error.message == "Spotify returned 2 playback fields; expected 7.")
        }
    }
}
