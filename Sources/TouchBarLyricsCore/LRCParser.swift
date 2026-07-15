import Foundation

public enum LRCParser {
    private static let timestampExpression = try! NSRegularExpression(
        pattern: #"\[(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?\]"#
    )
    private static let offsetExpression = try! NSRegularExpression(
        pattern: #"(?i)\[offset:\s*(-?\d+)\]"#
    )

    public static func parse(_ source: String) -> [LyricLine] {
        let offset = parseOffset(source)
        var parsed: [LyricLine] = []

        for rawLine in source.components(separatedBy: .newlines) {
            let range = NSRange(rawLine.startIndex..<rawLine.endIndex, in: rawLine)
            let matches = timestampExpression.matches(in: rawLine, range: range)
            guard let finalMatch = matches.last,
                  let textRange = Range(
                      NSRange(location: NSMaxRange(finalMatch.range), length: range.length - NSMaxRange(finalMatch.range)),
                      in: rawLine
                  ) else {
                continue
            }

            let trimmed = rawLine[textRange].trimmingCharacters(in: .whitespacesAndNewlines)
            let text = trimmed.isEmpty ? "♪" : trimmed

            for match in matches {
                guard let minuteRange = Range(match.range(at: 1), in: rawLine),
                      let secondRange = Range(match.range(at: 2), in: rawLine),
                      let minutes = Double(rawLine[minuteRange]),
                      let seconds = Double(rawLine[secondRange]) else {
                    continue
                }

                var fraction = 0.0
                if match.range(at: 3).location != NSNotFound,
                   let fractionRange = Range(match.range(at: 3), in: rawLine) {
                    let digits = String(rawLine[fractionRange])
                    if let value = Double(digits) {
                        fraction = value / pow(10, Double(digits.count))
                    }
                }

                parsed.append(
                    LyricLine(
                        time: max(0, minutes * 60 + seconds + fraction + offset),
                        text: text
                    )
                )
            }
        }

        return parsed.sorted {
            if $0.time == $1.time { return $0.text < $1.text }
            return $0.time < $1.time
        }
    }

    private static func parseOffset(_ source: String) -> TimeInterval {
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        guard let match = offsetExpression.firstMatch(in: source, range: range),
              let valueRange = Range(match.range(at: 1), in: source),
              let milliseconds = Double(source[valueRange]) else {
            return 0
        }
        return milliseconds / 1_000
    }
}

public enum LyricSelector {
    public static func currentLine(at position: TimeInterval, in lines: [LyricLine]) -> LyricLine? {
        guard !lines.isEmpty, position >= lines[0].time else { return nil }

        var lower = 0
        var upper = lines.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if lines[middle].time <= position {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lines[lower - 1]
    }
}
