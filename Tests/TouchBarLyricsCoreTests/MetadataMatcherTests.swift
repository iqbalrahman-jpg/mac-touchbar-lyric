import Testing
@testable import TouchBarLyricsCore

@Suite("LRCLIB metadata matching")
struct MetadataMatcherTests {
    private let track = TrackMetadata(
        id: "spotify:track:test",
        title: "Café Moon",
        artist: "The Artist",
        album: "Night",
        duration: 202
    )

    @Test("Normalizes punctuation, case, and diacritics")
    func normalization() {
        #expect(MetadataMatcher.normalized("  CAFÉ—Moon! ") == "cafe moon")
    }

    @Test("Chooses a synchronized candidate within duration tolerance")
    func choosesCandidate() {
        let candidates = [
            LRCLIBRecord(
                id: 1,
                trackName: "Cafe Moon",
                artistName: "the artist",
                albumName: "Night",
                duration: 203,
                instrumental: false,
                syncedLyrics: "[00:01]yes"
            ),
            LRCLIBRecord(
                id: 2,
                trackName: "Cafe Moon",
                artistName: "the artist",
                albumName: "Night",
                duration: 212,
                instrumental: false,
                syncedLyrics: "[00:01]wrong duration"
            )
        ]

        #expect(MetadataMatcher.choose(from: candidates, for: track)?.id == 1)
    }

    @Test("Rejects unsynchronized and mismatched candidates")
    func rejectsUnsafeMatches() {
        let candidates = [
            LRCLIBRecord(
                id: 1,
                trackName: "Different",
                artistName: "The Artist",
                albumName: nil,
                duration: 202,
                instrumental: false,
                syncedLyrics: "[00:01]wrong"
            ),
            LRCLIBRecord(
                id: 2,
                trackName: "Cafe Moon",
                artistName: "The Artist",
                albumName: nil,
                duration: 202,
                instrumental: false,
                syncedLyrics: nil
            )
        ]

        #expect(MetadataMatcher.choose(from: candidates, for: track) == nil)
    }

    @Test("Formats LRCLIB durations with a locale-independent decimal point")
    func formatsDurationForAPI() {
        #expect(LRCLIBClient.durationQueryValue(60.6819) == "60.682")
    }
}
