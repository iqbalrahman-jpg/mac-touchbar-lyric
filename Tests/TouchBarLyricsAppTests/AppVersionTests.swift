import Testing
@testable import TouchBarLyricsApp

@Suite("App version")
struct AppVersionTests {
    @Test("Shows the release version and build number")
    func releaseVersion() {
        let title = AppVersion.menuTitle(infoDictionary: [
            "CFBundleShortVersionString": "0.2.1",
            "CFBundleVersion": "3"
        ])

        #expect(title == "Version 0.2.1 (3)")
    }

    @Test("Handles a missing version")
    func missingVersion() {
        #expect(AppVersion.menuTitle(infoDictionary: nil) == "Version unknown")
    }
}
