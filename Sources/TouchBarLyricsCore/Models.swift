import Foundation

public struct TrackMetadata: Equatable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String
    public let duration: TimeInterval

    public init(
        id: String,
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
    }
}

public enum PlaybackState: String, Equatable, Sendable {
    case playing
    case paused
    case stopped
}

public struct PlaybackSnapshot: Equatable, Sendable {
    public let track: TrackMetadata?
    public let state: PlaybackState
    public let position: TimeInterval

    public init(track: TrackMetadata?, state: PlaybackState, position: TimeInterval) {
        self.track = track
        self.state = state
        self.position = position
    }

    public static let stopped = PlaybackSnapshot(track: nil, state: .stopped, position: 0)
}

public struct LyricLine: Equatable, Sendable {
    public let time: TimeInterval
    public let text: String

    public init(time: TimeInterval, text: String) {
        self.time = time
        self.text = text
    }
}

public struct PlaybackTimeline: Equatable, Sendable {
    private let basePosition: TimeInterval
    private let baseUptime: TimeInterval
    private let state: PlaybackState

    public init(position: TimeInterval, state: PlaybackState, uptime: TimeInterval) {
        self.basePosition = max(0, position)
        self.baseUptime = uptime
        self.state = state
    }

    public func position(at uptime: TimeInterval) -> TimeInterval {
        guard state == .playing else { return basePosition }
        return max(0, basePosition + max(0, uptime - baseUptime))
    }
}
