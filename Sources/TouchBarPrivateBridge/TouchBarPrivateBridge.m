#import "TouchBarPrivateBridge.h"

BOOL TBLPrivateTouchBarAPIAvailable(void) {
    return [NSTouchBar respondsToSelector:@selector(
        presentSystemModalTouchBar:placement:systemTrayItemIdentifier:
    )] && [NSTouchBar respondsToSelector:@selector(dismissSystemModalTouchBar:)]
        && [NSTouchBarItem respondsToSelector:@selector(addSystemTrayItem:)];
}

BOOL TBLPresentTouchBar(
    NSTouchBar *touchBar,
    NSTouchBarItemIdentifier systemTrayItemIdentifier
) {
    if (!TBLPrivateTouchBarAPIAvailable()) {
        return NO;
    }

    DFRSystemModalShowsCloseBoxWhenFrontMost(NO);
    [NSTouchBar presentSystemModalTouchBar:touchBar
                                 placement:0
                   systemTrayItemIdentifier:systemTrayItemIdentifier];
    return YES;
}

void TBLDismissTouchBar(NSTouchBar *touchBar) {
    if ([NSTouchBar respondsToSelector:@selector(dismissSystemModalTouchBar:)]) {
        [NSTouchBar dismissSystemModalTouchBar:touchBar];
    }
}

BOOL TBLInstallSystemTrayItem(
    NSTouchBarItem *item,
    NSTouchBarItemIdentifier identifier
) {
    if (![NSTouchBarItem respondsToSelector:@selector(addSystemTrayItem:)]) {
        return NO;
    }
    [NSTouchBarItem addSystemTrayItem:item];
    DFRElementSetControlStripPresenceForIdentifier(identifier, YES);
    return YES;
}

void TBLRemoveSystemTrayItem(
    NSTouchBarItem *item,
    NSTouchBarItemIdentifier identifier
) {
    DFRElementSetControlStripPresenceForIdentifier(identifier, NO);
    if ([NSTouchBarItem respondsToSelector:@selector(removeSystemTrayItem:)]) {
        [NSTouchBarItem removeSystemTrayItem:item];
    }
}
