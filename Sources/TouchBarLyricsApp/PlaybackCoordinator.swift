import Foundation
import TouchBarLyricsCore

@MainActor
final class PlaybackCoordinator {
    var onStatusChange: ((String) -> Void)?
    var onEnabledChange: ((Bool) -> Void)?

    private let monitor: SpotifyMonitor
    private let presenter: TouchBarPresenter
    private let lyricsClient: LRCLIBClient
    private var displayTimer: Timer?
    private var fetchTask: Task<Void, Never>?
    private var cache: [String: [LyricLine]] = [:]
    private var currentTrack: TrackMetadata?
    private var timeline: PlaybackTimeline?
    private var playbackState: PlaybackState = .stopped
    private var lyricLines: [LyricLine] = []
    private var displayedText: String?
    private(set) var isEnabled = true

    init(
        monitor: SpotifyMonitor = SpotifyMonitor(),
        presenter: TouchBarPresenter = TouchBarPresenter(),
        lyricsClient: LRCLIBClient = LRCLIBClient()
    ) {
        self.monitor = monitor
        self.presenter = presenter
        self.lyricsClient = lyricsClient

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
    }

    func start() {
        guard presenter.privateAPIAvailable else {
            setStatus("Touch Bar private API is unavailable on this macOS version")
            return
        }

        setStatus("Waiting for Spotify…")
        monitor.start()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateDisplayedLine() }
        }
        timer.tolerance = 0.02
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    func stop() {
        fetchTask?.cancel()
        fetchTask = nil
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

    private func handle(_ result: Result<PlaybackSnapshot, SpotifyReadError>) {
        switch result {
        case .failure(let error):
            fetchTask?.cancel()
            currentTrack = nil
            lyricLines = []
            timeline = nil
            presenter.dismiss()
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
            presenter.dismiss()
            setStatus("Spotify is not playing")
            return
        }

        timeline = PlaybackTimeline(
            position: snapshot.position,
            state: snapshot.state,
            uptime: ProcessInfo.processInfo.systemUptime
        )

        if currentTrack?.id != track.id {
            beginTrack(track)
        } else {
            updateDisplayedLine()
        }
    }

    private func beginTrack(_ track: TrackMetadata) {
        fetchTask?.cancel()
        currentTrack = track
        lyricLines = []
        displayedText = nil

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
                self.setStatus("Showing lyrics for \(track.title)")
                self.updateDisplayedLine(force: true)
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.currentTrack?.id == track.id else { return }
                self.lyricLines = []
                self.displayedText = "Synced lyrics unavailable"
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
        let text = LyricSelector.currentLine(at: position, in: lyricLines)?.text ?? "♪"
        guard force || text != displayedText else { return }

        displayedText = text
        presenter.show(text: text, dimmed: playbackState == .paused)
    }

    private func setStatus(_ status: String) {
        onStatusChange?(status)
    }
}
