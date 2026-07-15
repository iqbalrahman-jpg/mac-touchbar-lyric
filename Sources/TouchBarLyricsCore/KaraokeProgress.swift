import Foundation

public struct KaraokeLineProgress: Equatable, Sendable {
    public let line: LyricLine
    public let progress: Double

    public init(line: LyricLine, progress: Double) {
        self.line = line
        self.progress = progress
    }
}

public enum KaraokeProgress {
    private static let playbackLead: TimeInterval = 0.2
    private static let estimatedSecondsPerWord: TimeInterval = 0.45
    private static let minimumVocalDuration: TimeInterval = 1

    public static func current(
        at position: TimeInterval,
        in lines: [LyricLine],
        trackDuration: TimeInterval
    ) -> KaraokeLineProgress? {
        guard let index = LyricSelector.currentLineIndex(at: position, in: lines) else {
            return nil
        }

        let line = lines[index]
        let wordCount = line.text.split(whereSeparator: \.isWhitespace).count
        guard wordCount > 0 else {
            return KaraokeLineProgress(line: line, progress: 0)
        }

        let endTime = index + 1 < lines.count
            ? lines[index + 1].time
            : trackDuration
        let duration = endTime - line.time
        guard duration > 0 else {
            return KaraokeLineProgress(line: line, progress: 1)
        }

        let estimatedVocalDuration = min(
            duration,
            max(minimumVocalDuration, Double(wordCount) * estimatedSecondsPerWord)
        )
        let lineProgress = max(
            0,
            min(1, (position - line.time + playbackLead) / estimatedVocalDuration)
        )
        return KaraokeLineProgress(
            line: line,
            progress: lineProgress
        )
    }
}
