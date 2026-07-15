import Testing
@testable import TouchBarLyricsCore

@Suite("Lyric selection")
struct LyricSelectorTests {
    private let lines = [
        LyricLine(time: 1, text: "One"),
        LyricLine(time: 3, text: "Two"),
        LyricLine(time: 5, text: "Three")
    ]

    @Test("Returns no line before the first timestamp")
    func beforeFirstLine() {
        #expect(LyricSelector.currentLine(at: 0.99, in: lines) == nil)
    }

    @Test("Uses the line at an exact timestamp")
    func exactTimestamp() {
        #expect(LyricSelector.currentLine(at: 3, in: lines)?.text == "Two")
    }

    @Test("Keeps the latest line between timestamps and after the end")
    func betweenAndAfterLines() {
        #expect(LyricSelector.currentLine(at: 4.9, in: lines)?.text == "Two")
        #expect(LyricSelector.currentLine(at: 99, in: lines)?.text == "Three")
    }
}
