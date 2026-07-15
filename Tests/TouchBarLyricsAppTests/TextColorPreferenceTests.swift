@preconcurrency import AppKit
import Foundation
import Testing
@testable import TouchBarLyricsApp

@Suite("Text color preference")
struct TextColorPreferenceTests {
    @Test("Saves and restores an sRGB color")
    func roundTrip() throws {
        let (defaults, suiteName) = try testDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let original = NSColor(srgbRed: 0.2, green: 0.4, blue: 0.8, alpha: 1)

        TextColorPreference.save(original, to: defaults)
        let restored = try #require(TextColorPreference.load(from: defaults))

        #expect(abs(restored.redComponent - 0.2) < 0.001)
        #expect(abs(restored.greenComponent - 0.4) < 0.001)
        #expect(abs(restored.blueComponent - 0.8) < 0.001)
        #expect(abs(restored.alphaComponent - 1) < 0.001)
    }

    @Test("Rejects malformed stored components")
    func malformedValue() throws {
        let (defaults, suiteName) = try testDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set([2.0, 0.4, 0.8, 1.0], forKey: TextColorPreference.defaultsKey)

        #expect(TextColorPreference.load(from: defaults) == nil)
    }

    @Test("Reset removes the saved color")
    func reset() throws {
        let (defaults, suiteName) = try testDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        TextColorPreference.save(.systemPink, to: defaults)

        TextColorPreference.reset(in: defaults)

        #expect(TextColorPreference.load(from: defaults) == nil)
    }

    private func testDefaults() throws -> (UserDefaults, String) {
        let suiteName = "TouchBarLyrics.TextColorPreferenceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
