import Testing
@testable import TouchBarLyricsApp

@Suite("Touch Bar presentation state")
struct TouchBarPresentationStateTests {
    @Test("New content presents once but lyric updates do not reopen it")
    func contentUpdates() {
        var state = TouchBarPresentationState()

        let initialPresentation = state.showContent()
        let lyricUpdatePresentation = state.showContent()

        #expect(initialPresentation)
        #expect(!lyricUpdatePresentation)
    }

    @Test("Manual dismissal persists until an explicit reveal")
    func manualDismissal() {
        var state = TouchBarPresentationState()
        let initialPresentation = state.showContent()
        state.observeVisibility(true)
        state.observeVisibility(false)

        #expect(initialPresentation)
        #expect(state.isDismissedByUser)
        #expect(!state.shouldRestoreAfterAppSwitch)
        let lyricUpdatePresentation = state.showContent()
        let explicitRevealPresentation = state.reveal()
        #expect(!lyricUpdatePresentation)
        #expect(explicitRevealPresentation)
        #expect(state.shouldRestoreAfterAppSwitch)
    }

    @Test("A temporary hide during an app switch remains restorable")
    func temporaryAppSwitchHide() {
        var state = TouchBarPresentationState()
        let initialPresentation = state.showContent()
        state.observeVisibility(true)
        state.observeVisibility(false, temporaryHide: true)

        #expect(initialPresentation)
        #expect(!state.isDismissedByUser)
        #expect(state.shouldRestoreAfterAppSwitch)
    }

    @Test("Programmatic hiding is not treated as manual dismissal")
    func programmaticHide() {
        var state = TouchBarPresentationState()
        let initialPresentation = state.showContent()
        state.observeVisibility(true)
        state.hideContent()
        state.observeVisibility(false)

        #expect(initialPresentation)
        #expect(!state.isDismissedByUser)
        #expect(!state.shouldRestoreAfterAppSwitch)
        let replacementPresentation = state.showContent()
        #expect(replacementPresentation)
    }

    @Test("Dismissal remains in effect across content removal and replacement")
    func dismissalAcrossTracks() {
        var state = TouchBarPresentationState()
        let initialPresentation = state.showContent()
        state.observeVisibility(true)
        state.observeVisibility(false)
        state.hideContent()

        let replacementPresentation = state.showContent()
        #expect(initialPresentation)
        #expect(!replacementPresentation)
        #expect(state.isDismissedByUser)
    }
}
