import Testing
@testable import TouchBarLyricsCore

@Suite("LRC parsing")
struct LRCParserTests {
    @Test("Parses common timestamp precision")
    func parsesTimestamps() {
        let lines = LRCParser.parse("""
        [00:01.50]First
        [01:02.345]Second
        [02:03]Third
        """)

        #expect(lines == [
            LyricLine(time: 1.5, text: "First"),
            LyricLine(time: 62.345, text: "Second"),
            LyricLine(time: 123, text: "Third")
        ])
    }

    @Test("Expands multiple timestamps and represents instrumental gaps")
    func parsesMultipleTimestamps() {
        let lines = LRCParser.parse("""
        [00:02.00][00:04.00]Again
        [00:06.00]
        """)

        #expect(lines == [
            LyricLine(time: 2, text: "Again"),
            LyricLine(time: 4, text: "Again"),
            LyricLine(time: 6, text: "♪")
        ])
    }

    @Test("Applies millisecond offset and clamps negative times")
    func appliesOffset() {
        let lines = LRCParser.parse("""
        [offset:-500]
        [00:00.20]Start
        [00:02.00]Next
        """)

        #expect(lines == [
            LyricLine(time: 0, text: "Start"),
            LyricLine(time: 1.5, text: "Next")
        ])
    }

    @Test("Ignores metadata and malformed lines")
    func ignoresMalformedLines() {
        let lines = LRCParser.parse("""
        [ar:Artist]
        no timestamp
        [broken]text
        """)

        #expect(lines.isEmpty)
    }
}
