import AppKit
import Foundation
import TouchBarLyricsCore

struct SpotifyReadError: Error, Sendable {
    let message: String
}

enum SpotifyReader {
    nonisolated static func read() -> Result<PlaybackSnapshot, SpotifyReadError> {
        guard !NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.spotify.client"
        ).isEmpty else {
            return .success(.stopped)
        }

        let source = """
        tell application "Spotify"
            set playbackState to (player state as text)
            if playbackState is "stopped" then return {playbackState}
            set currentItem to current track
            return {id of currentItem, name of currentItem, artist of currentItem, ¬
                album of currentItem, duration of currentItem, player position, playbackState, ¬
                artwork url of currentItem}
        end tell
        """

        guard let script = NSAppleScript(source: source) else {
            return .failure(SpotifyReadError(message: "Could not create Spotify automation."))
        }

        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let detail = errorInfo[NSAppleScript.errorMessage] as? String
                ?? "macOS denied Spotify automation."
            return .failure(SpotifyReadError(message: detail))
        }

        return decode(descriptor)
    }

    nonisolated static func decode(
        _ descriptor: NSAppleEventDescriptor
    ) -> Result<PlaybackSnapshot, SpotifyReadError> {
        if descriptor.numberOfItems == 1,
           descriptor.atIndex(1)?.stringValue == PlaybackState.stopped.rawValue {
            return .success(.stopped)
        }

        guard descriptor.numberOfItems == 8 else {
            return .failure(
                SpotifyReadError(
                    message: "Spotify returned \(descriptor.numberOfItems) playback fields; expected 8."
                )
            )
        }

        guard let trackID = descriptor.atIndex(1)?.stringValue,
              let title = descriptor.atIndex(2)?.stringValue,
              let artist = descriptor.atIndex(3)?.stringValue,
              let album = descriptor.atIndex(4)?.stringValue,
              let stateValue = descriptor.atIndex(7)?.stringValue else {
            return .failure(SpotifyReadError(message: "Spotify returned incomplete track metadata."))
        }

        guard let state = PlaybackState(rawValue: stateValue) else {
            return .failure(
                SpotifyReadError(message: "Spotify returned unsupported state “\(stateValue)”.")
            )
        }

        // Reading numeric Apple Event descriptors directly avoids localized
        // decimal strings such as `60,6819` on Indonesian locale settings.
        let durationMilliseconds = descriptor.atIndex(5)?.doubleValue ?? 0
        let position = descriptor.atIndex(6)?.doubleValue ?? -1
        guard durationMilliseconds > 0, position >= 0 else {
            return .failure(SpotifyReadError(message: "Spotify returned invalid playback timing."))
        }

        let artworkURL = descriptor.atIndex(8)?.stringValue.flatMap { value -> URL? in
            guard let url = URL(string: value),
                  url.scheme == "https" || url.scheme == "http" else {
                return nil
            }
            return url
        }
        let track = TrackMetadata(
            id: trackID,
            title: title,
            artist: artist,
            album: album,
            duration: durationMilliseconds / 1_000,
            artworkURL: artworkURL
        )
        return .success(PlaybackSnapshot(track: track, state: state, position: position))
    }
}

@MainActor
final class SpotifyMonitor {
    var onResult: ((Result<PlaybackSnapshot, SpotifyReadError>) -> Void)?

    private var timer: Timer?
    private var pollInFlight = false
    private var refreshRequested = false

    func start() {
        stop()
        poll()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        if pollInFlight {
            refreshRequested = true
        } else {
            poll()
        }
    }

    private func poll() {
        guard !pollInFlight else { return }
        pollInFlight = true
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                SpotifyReader.read()
            }.value
            guard let self else { return }
            self.pollInFlight = false
            self.onResult?(result)
            if self.refreshRequested {
                self.refreshRequested = false
                self.poll()
            }
        }
    }
}
