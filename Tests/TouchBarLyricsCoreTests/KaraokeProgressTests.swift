import Testing
@testable import TouchBarLyricsCore

@Suite("Estimated karaoke progress")
struct KaraokeProgressTests {
    private let lines = [
        LyricLine(time: 10, text: "you should be giving me love"),
        LyricLine(time: 16, text: "next line")
    ]

    @Test("Returns no progress before the first line")
    func beforeFirstLine() {
        #expect(KaraokeProgress.current(at: 9.9, in: lines, trackDuration: 20) == nil)
    }

    @Test("Starts with a small playback lead when a line begins")
    func lineStart() {
        let progress = KaraokeProgress.current(at: 10, in: lines, trackDuration: 20)

        #expect(progress?.line.text == "you should be giving me love")
        #expect((progress?.progress ?? 0) > 0)
        #expect((progress?.progress ?? 1) < 0.1)
    }

    @Test("Advances continuously instead of jumping between words")
    func continuousProgress() {
        let first = KaraokeProgress.current(at: 10.5, in: lines, trackDuration: 20)?.progress
        let second = KaraokeProgress.current(at: 10.6, in: lines, trackDuration: 20)?.progress

        #expect((first ?? 0) > 0)
        #expect((second ?? 0) > (first ?? 1))
        #expect((second ?? 1) < 1)
    }

    @Test("Finishes before a long pause leading to the next line")
    func excludesTrailingPause() {
        let progress = KaraokeProgress.current(at: 13, in: lines, trackDuration: 20)

        #expect(progress?.progress == 1)
    }

    @Test("Uses the track duration for the final line")
    func finalLine() {
        let progress = KaraokeProgress.current(at: 18, in: lines, trackDuration: 20)

        #expect(progress?.line.text == "next line")
        #expect(progress?.progress == 1)
    }

    @Test("Treats punctuation as part of its word")
    func punctuation() {
        let punctuationLines = [LyricLine(time: 0, text: "hello,   world!")]

        let start = KaraokeProgress.current(at: 0, in: punctuationLines, trackDuration: 2)
        let finish = KaraokeProgress.current(at: 1, in: punctuationLines, trackDuration: 2)

        #expect((start?.progress ?? 0) > 0)
        #expect(finish?.progress == 1)
    }
}
