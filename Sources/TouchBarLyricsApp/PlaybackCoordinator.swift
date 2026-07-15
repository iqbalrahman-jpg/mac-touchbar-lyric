@preconcurrency import AppKit
import Foundation
import TouchBarLyricsCore

@MainActor
final class PlaybackCoordinator {
    var onStatusChange: ((String) -> Void)?
    var onEnabledChange: ((Bool) -> Void)?

    private let monitor: SpotifyMonitor
    private let presenter: TouchBarPresenter
    private let lyricsClient: LRCLIBClient
    private let artworkLoader: ArtworkLoader
    private var displayTimer: Timer?
    private var fetchTask: Task<Void, Never>?
    private var commandTask: Task<Void, Never>?
    private var cache: [String: [LyricLine]] = [:]
    private var currentTrack: TrackMetadata?
    private var timeline: PlaybackTimeline?
    private var playbackState: PlaybackState = .stopped
    private var lyricLines: [LyricLine] = []
    private var displayedText: String?
    private var displayedProgress: Double?
    private var displayedDimmed: Bool?
    private var currentArtworkURL: URL?
    private var isCommandInFlight = false
    private(set) var isEnabled = true

    var textColor: NSColor {
        presenter.textColor
    }

    init(
        monitor: SpotifyMonitor = SpotifyMonitor(),
        presenter: TouchBarPresenter = TouchBarPresenter(),
        lyricsClient: LRCLIBClient = LRCLIBClient(),
        artworkLoader: ArtworkLoader = ArtworkLoader()
    ) {
        self.monitor = monitor
        self.presenter = presenter
        self.lyricsClient = lyricsClient
        self.artworkLoader = artworkLoader

        monitor.onResult = { [weak self] result in
            self?.handle(result)
        }
        presenter.onRevealRequested = { [weak self] in
            guard let self else { return }
            if self.isEnabled {
                self.presenter.reveal()
            } else {
                self.setEnabled(true)
            }
        }
        presenter.onPlaybackCommandRequested = { [weak self] command in
            self?.perform(command)
        }
    }

    func start() {
        guard presenter.privateAPIAvailable else {
            setStatus("Touch Bar private API is unavailable on this macOS version")
            return
        }

        setStatus("Waiting for Spotify…")
        monitor.start()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateDisplayedLine() }
        }
        timer.tolerance = 0.005
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    func stop() {
        fetchTask?.cancel()
        fetchTask = nil
        commandTask?.cancel()
        commandTask = nil
        artworkLoader.cancel()
        displayTimer?.invalidate()
        displayTimer = nil
        monitor.stop()
        presenter.tearDown()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        onEnabledChange?(enabled)
        if enabled {
            presenter.reveal()
            setStatus(currentTrack == nil ? "Waiting for Spotify…" : "Touch Bar lyrics enabled")
            updateDisplayedLine(force: true)
        } else {
            presenter.dismiss()
            setStatus("Touch Bar lyrics disabled")
        }
    }

    func setTextColor(_ color: NSColor) {
        presenter.setTextColor(color)
    }

    private func handle(_ result: Result<PlaybackSnapshot, SpotifyReadError>) {
        switch result {
        case .failure(let error):
            fetchTask?.cancel()
            currentTrack = nil
            lyricLines = []
            timeline = nil
            displayedText = "Spotify unavailable"
            displayedProgress = nil
            displayedDimmed = true
            currentArtworkURL = nil
            artworkLoader.cancel()
            presenter.setArtwork(nil)
            presenter.setTrackTitle(nil)
            presenter.setArtworkInteractionEnabled(false)
            if isEnabled {
                presenter.show(text: "Spotify unavailable", dimmed: true)
            }
            setStatus("Spotify access failed: \(error.message)")

        case .success(let snapshot):
            handle(snapshot)
        }
    }

    private func handle(_ snapshot: PlaybackSnapshot) {
        playbackState = snapshot.state

        guard snapshot.state != .stopped, let track = snapshot.track else {
            fetchTask?.cancel()
            currentTrack = nil
            lyricLines = []
            timeline = nil
            displayedText = nil
            displayedProgress = nil
            displayedDimmed = nil
            currentArtworkURL = nil
            artworkLoader.cancel()
            presenter.setArtwork(nil)
            presenter.setTrackTitle(nil)
            presenter.setArtworkInteractionEnabled(false)
            if isEnabled {
                displayedText = "Spotify is not playing"
                displayedDimmed = true
                presenter.show(text: "Spotify is not playing", dimmed: true)
            }
            setStatus("Spotify is not playing")
            return
        }

        timeline = PlaybackTimeline(
            position: snapshot.position,
            state: snapshot.state,
            uptime: ProcessInfo.processInfo.systemUptime
        )
        presenter.setTrackTitle(track.title)
        presenter.setArtworkInteractionEnabled(!isCommandInFlight)

        if currentTrack?.id != track.id {
            beginTrack(track)
        } else {
            currentTrack = track
            updateDisplayedLine()
        }
        updateArtwork(for: track)
    }

    private func beginTrack(_ track: TrackMetadata) {
        fetchTask?.cancel()
        currentTrack = track
        lyricLines = []
        displayedText = nil
        displayedProgress = nil
        displayedDimmed = nil

        if let cached = cache[track.id] {
            lyricLines = cached
            setStatus("Showing lyrics for \(track.title)")
            updateDisplayedLine(force: true)
            return
        }

        if isEnabled {
            presenter.show(text: "Loading lyrics…", dimmed: playbackState == .paused)
        }
        setStatus("Loading lyrics for \(track.title)…")

        fetchTask = Task { [weak self, lyricsClient] in
            do {
                let lines = try await lyricsClient.synchronizedLyrics(for: track)
                try Task.checkCancellation()
                guard let self, self.currentTrack?.id == track.id else { return }
                self.cache[track.id] = lines
                self.lyricLines = lines
                self.displayedText = nil
                self.displayedProgress = nil
                self.displayedDimmed = nil
                self.setStatus("Showing lyrics for \(track.title)")
                self.updateDisplayedLine(force: true)
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.currentTrack?.id == track.id else { return }
                self.lyricLines = []
                self.displayedText = "Synced lyrics unavailable"
                self.displayedProgress = nil
                self.displayedDimmed = self.playbackState == .paused
                if self.isEnabled {
                    self.presenter.show(
                        text: "Synced lyrics unavailable",
                        dimmed: self.playbackState == .paused
                    )
                }
                self.setStatus("No synchronized lyrics for \(track.title)")
            }
        }
    }

    private func updateDisplayedLine(force: Bool = false) {
        guard isEnabled, currentTrack != nil, let timeline else { return }
        guard !lyricLines.isEmpty else { return }

        let position = timeline.position(at: ProcessInfo.processInfo.systemUptime)
        let progress = KaraokeProgress.current(
            at: position,
            in: lyricLines,
            trackDuration: currentTrack?.duration ?? position
        )
        let text = progress?.line.text ?? "♪"
        let fillProgress = text == "♪" ? nil : progress?.progress
        let dimmed = playbackState == .paused
        guard force
                || text != displayedText
                || fillProgress != displayedProgress
                || dimmed != displayedDimmed else {
            return
        }

        displayedText = text
        displayedProgress = fillProgress
        displayedDimmed = dimmed
        presenter.show(
            text: text,
            progress: fillProgress,
            dimmed: dimmed
        )
    }

    private func updateArtwork(for track: TrackMetadata) {
        guard track.artworkURL != currentArtworkURL else { return }
        currentArtworkURL = track.artworkURL
        presenter.setArtwork(nil)
        artworkLoader.load(track.artworkURL) { [weak self] url, image in
            guard let self,
                  self.currentTrack?.artworkURL == url,
                  self.currentArtworkURL == url else {
                return
            }
            self.presenter.setArtwork(image)
        }
    }

    private func perform(_ command: SpotifyPlaybackCommand) {
        guard !isCommandInFlight,
              currentTrack != nil,
              playbackState != .stopped else {
            return
        }

        isCommandInFlight = true
        presenter.setArtworkInteractionEnabled(false)
        commandTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                SpotifyController.execute(command)
            }.value
            guard let self, !Task.isCancelled else { return }
            self.isCommandInFlight = false
            self.presenter.setArtworkInteractionEnabled(
                self.currentTrack != nil && self.playbackState != .stopped
            )
            switch result {
            case .success:
                self.monitor.refresh()
            case .failure(let error):
                self.setStatus("Spotify control failed: \(error.message)")
            }
        }
    }

    private func setStatus(_ status: String) {
        onStatusChange?(status)
    }
}
