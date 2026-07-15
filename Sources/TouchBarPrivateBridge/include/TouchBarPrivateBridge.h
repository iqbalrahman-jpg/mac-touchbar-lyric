#ifndef TouchBarPrivateBridge_h
#define TouchBarPrivateBridge_h

#import <AppKit/AppKit.h>

// These APIs are private and unsupported. Keeping the declarations in one
// module makes the compatibility boundary explicit and easy to replace.
extern void DFRElementSetControlStripPresenceForIdentifier(
    NSTouchBarItemIdentifier _Nonnull identifier,
    BOOL presence
);
extern void DFRSystemModalShowsCloseBoxWhenFrontMost(BOOL show);

@interface NSTouchBar (TouchBarLyricsPrivateMethods)
+ (void)presentSystemModalTouchBar:(NSTouchBar * _Nonnull)touchBar
                          placement:(long long)placement
            systemTrayItemIdentifier:(NSTouchBarItemIdentifier _Nullable)identifier;
+ (void)dismissSystemModalTouchBar:(NSTouchBar * _Nonnull)touchBar;
+ (void)minimizeSystemModalTouchBar:(NSTouchBar * _Nonnull)touchBar;
@end

@interface NSTouchBarItem (TouchBarLyricsPrivateMethods)
+ (void)addSystemTrayItem:(NSTouchBarItem * _Nonnull)item;
+ (void)removeSystemTrayItem:(NSTouchBarItem * _Nonnull)item;
@end

BOOL TBLPrivateTouchBarAPIAvailable(void);
BOOL TBLPresentTouchBar(
    NSTouchBar * _Nonnull touchBar,
    NSTouchBarItemIdentifier _Nonnull systemTrayItemIdentifier
);
void TBLDismissTouchBar(NSTouchBar * _Nonnull touchBar);
BOOL TBLInstallSystemTrayItem(
    NSTouchBarItem * _Nonnull item,
    NSTouchBarItemIdentifier _Nonnull identifier
);
void TBLRemoveSystemTrayItem(
    NSTouchBarItem * _Nonnull item,
    NSTouchBarItemIdentifier _Nonnull identifier
);

#endif
