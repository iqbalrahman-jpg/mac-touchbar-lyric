@preconcurrency import AppKit
import Foundation

enum SpotifyPlaybackCommand: Equatable, Sendable {
    case previous
    case playPause
    case next

    var appleScriptCommand: String {
        switch self {
        case .previous: "previous track"
        case .playPause: "playpause"
        case .next: "next track"
        }
    }
}

enum SpotifyController {
    nonisolated static func execute(
        _ command: SpotifyPlaybackCommand
    ) -> Result<Void, SpotifyReadError> {
        let source = "tell application \"Spotify\" to \(command.appleScriptCommand)"
        guard let script = NSAppleScript(source: source) else {
            return .failure(
                SpotifyReadError(message: "Could not create Spotify playback automation.")
            )
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let detail = errorInfo[NSAppleScript.errorMessage] as? String
                ?? "Spotify playback control failed."
            return .failure(SpotifyReadError(message: detail))
        }
        return .success(())
    }
}
