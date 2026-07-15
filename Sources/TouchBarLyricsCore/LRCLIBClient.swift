import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum LRCLIBError: Error, Equatable, LocalizedError {
    case invalidURL
    case requestFailed
    case noSyncedLyrics
    case malformedLyrics

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "Could not create the LRCLIB request."
        case .requestFailed: "LRCLIB did not return a successful response."
        case .noSyncedLyrics: "Synced lyrics are unavailable."
        case .malformedLyrics: "The synchronized lyrics could not be parsed."
        }
    }
}

public struct LRCLIBRecord: Decodable, Equatable, Sendable {
    public let id: Int
    public let trackName: String
    public let artistName: String
    public let albumName: String?
    public let duration: TimeInterval
    public let instrumental: Bool
    public let syncedLyrics: String?
}

public struct MetadataMatcher {
    public static func choose(
        from records: [LRCLIBRecord],
        for track: TrackMetadata,
        durationTolerance: TimeInterval = 3
    ) -> LRCLIBRecord? {
        records
            .filter { record in
                normalized(record.trackName) == normalized(track.title)
                    && normalized(record.artistName) == normalized(track.artist)
                    && abs(record.duration - track.duration) <= durationTolerance
                    && !(record.syncedLyrics?.isEmpty ?? true)
            }
            .min { abs($0.duration - track.duration) < abs($1.duration - track.duration) }
    }

    public static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? String($0) : " " }
            .joined()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

public struct LRCLIBClient: Sendable {
    private let session: URLSession
    private let baseURL: URL

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://lrclib.net")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    public func synchronizedLyrics(for track: TrackMetadata) async throws -> [LyricLine] {
        if let exact = try? await exactRecord(for: track),
           let source = exact.syncedLyrics,
           !source.isEmpty {
            return try parsed(source)
        }

        let candidates = try await searchRecords(for: track)
        guard let match = MetadataMatcher.choose(from: candidates, for: track),
              let source = match.syncedLyrics else {
            throw LRCLIBError.noSyncedLyrics
        }
        return try parsed(source)
    }

    private func exactRecord(for track: TrackMetadata) async throws -> LRCLIBRecord {
        let url = try endpoint(
            path: "/api/get",
            items: [
                URLQueryItem(name: "track_name", value: track.title),
                URLQueryItem(name: "artist_name", value: track.artist),
                URLQueryItem(name: "album_name", value: track.album),
                URLQueryItem(
                    name: "duration",
                    value: Self.durationQueryValue(track.duration)
                )
            ]
        )
        return try await request(url, as: LRCLIBRecord.self)
    }

    private func searchRecords(for track: TrackMetadata) async throws -> [LRCLIBRecord] {
        let url = try endpoint(
            path: "/api/search",
            items: [
                URLQueryItem(name: "track_name", value: track.title),
                URLQueryItem(name: "artist_name", value: track.artist)
            ]
        )
        return try await request(url, as: [LRCLIBRecord].self)
    }

    private func endpoint(path: String, items: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw LRCLIBError.invalidURL
        }
        components.queryItems = items
        guard let url = components.url else { throw LRCLIBError.invalidURL }
        return url
    }

    private func request<T: Decodable & Sendable>(_ url: URL, as type: T.Type) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue(
            "TouchBarLyrics/0.1 (https://github.com/iqbalrahman/mac-touchbar)",
            forHTTPHeaderField: "User-Agent"
        )

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw LRCLIBError.requestFailed
            }
            return try JSONDecoder().decode(type, from: data)
        } catch let error as LRCLIBError {
            throw error
        } catch {
            throw LRCLIBError.requestFailed
        }
    }

    private func parsed(_ source: String) throws -> [LyricLine] {
        let lines = LRCParser.parse(source)
        guard !lines.isEmpty else { throw LRCLIBError.malformedLyrics }
        return lines
    }

    static func durationQueryValue(_ duration: TimeInterval) -> String {
        String(
            format: "%.3f",
            locale: Locale(identifier: "en_US_POSIX"),
            duration
        )
    }
}
