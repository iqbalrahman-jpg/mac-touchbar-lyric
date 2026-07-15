struct TouchBarPresentationState {
    private(set) var hasContent = false
    private(set) var isDismissedByUser = false
    private var hasBeenVisible = false

    var shouldRestoreAfterAppSwitch: Bool {
        hasContent && !isDismissedByUser
    }

    mutating func showContent() -> Bool {
        let shouldPresent = !hasContent && !isDismissedByUser
        hasContent = true
        return shouldPresent
    }

    mutating func hideContent() {
        hasContent = false
        hasBeenVisible = false
    }

    mutating func reveal() -> Bool {
        isDismissedByUser = false
        return hasContent
    }

    mutating func observeVisibility(_ isVisible: Bool, temporaryHide: Bool = false) {
        if isVisible {
            hasBeenVisible = true
            return
        }

        guard hasContent, hasBeenVisible else { return }
        hasBeenVisible = false
        if !temporaryHide {
            isDismissedByUser = true
        }
    }
}
