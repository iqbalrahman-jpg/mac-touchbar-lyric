@preconcurrency import AppKit
import Foundation

@MainActor
final class ArtworkLoader {
    typealias Fetcher = @Sendable (URL) async throws -> (Data, URLResponse)

    private let fetcher: Fetcher
    private let cache = NSCache<NSURL, NSImage>()
    private var task: Task<Void, Never>?
    private var requestID: UUID?

    init(
        fetcher: @escaping Fetcher = { url in
            try await URLSession.shared.data(from: url)
        }
    ) {
        self.fetcher = fetcher
    }

    func load(
        _ url: URL?,
        completion: @escaping @MainActor (URL, NSImage?) -> Void
    ) {
        cancel()
        guard let url else { return }

        if let image = cache.object(forKey: url as NSURL) {
            completion(url, image)
            return
        }

        let requestID = UUID()
        self.requestID = requestID
        task = Task { [weak self, fetcher] in
            do {
                let (data, response) = try await fetcher(url)
                try Task.checkCancellation()
                guard let self,
                      self.requestID == requestID else {
                    return
                }
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      let image = NSImage(data: data) else {
                    completion(url, nil)
                    return
                }
                self.cache.setObject(image, forKey: url as NSURL)
                completion(url, image)
            } catch {
                guard let self, self.requestID == requestID else { return }
                completion(url, nil)
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        requestID = nil
    }
}
