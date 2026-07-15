@preconcurrency import AppKit
import Foundation
import Testing
@testable import TouchBarLyricsApp

private actor FetchCounter {
    private var value = 0

    func increment() {
        value += 1
    }

    func count() -> Int {
        value
    }
}

@MainActor
@Suite("Artwork loading")
struct ArtworkLoaderTests {
    @Test("Reuses cached artwork")
    func cache() async throws {
        let url = try #require(URL(string: "https://i.scdn.co/image/cache-test"))
        let data = try imageData()
        let response = try response(for: url)
        let counter = FetchCounter()
        let loader = ArtworkLoader { _ in
            await counter.increment()
            return (data, response)
        }

        let first = await load(url, with: loader)
        let second = await load(url, with: loader)

        #expect(first != nil)
        #expect(second != nil)
        #expect(await counter.count() == 1)
    }

    @Test("A stale request cannot replace newer artwork")
    func staleRequest() async throws {
        let oldURL = try #require(URL(string: "https://i.scdn.co/image/old"))
        let newURL = try #require(URL(string: "https://i.scdn.co/image/new"))
        let data = try imageData()
        let loader = ArtworkLoader { url in
            if url == oldURL {
                try? await Task.sleep(for: .milliseconds(100))
            }
            return (data, try Self.response(for: url))
        }
        var completedURLs: [URL] = []

        loader.load(oldURL) { url, _ in completedURLs.append(url) }
        let newImage = await load(newURL, with: loader)
        try? await Task.sleep(for: .milliseconds(150))

        #expect(newImage != nil)
        #expect(completedURLs.isEmpty)
    }

    private func load(_ url: URL, with loader: ArtworkLoader) async -> NSImage? {
        await withCheckedContinuation { continuation in
            loader.load(url) { _, image in
                continuation.resume(returning: image)
            }
        }
    }

    private func imageData() throws -> Data {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.systemGreen.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 2, height: 2)).fill()
        image.unlockFocus()
        return try #require(image.tiffRepresentation)
    }

    nonisolated private static func response(for url: URL) throws -> HTTPURLResponse {
        try #require(
            HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "image/jpeg"]
            )
        )
    }

    private func response(for url: URL) throws -> HTTPURLResponse {
        try Self.response(for: url)
    }
}
