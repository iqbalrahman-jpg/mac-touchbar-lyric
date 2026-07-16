@preconcurrency import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = PlaybackCoordinator()
    private var statusItem: NSStatusItem?
    private let statusMenuItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let versionMenuItem = NSMenuItem(
        title: AppVersion.menuTitle(infoDictionary: Bundle.main.infoDictionary),
        action: nil,
        keyEquivalent: ""
    )
    private let enabledMenuItem = NSMenuItem(
        title: "Show Lyrics on Touch Bar",
        action: #selector(toggleLyrics),
        keyEquivalent: ""
    )
    private let loginMenuItem = NSMenuItem(
        title: "Launch at Login",
        action: #selector(toggleLaunchAtLogin),
        keyEquivalent: ""
    )
    private let textColorMenuItem = NSMenuItem(
        title: "Text Color…",
        action: #selector(chooseTextColor),
        keyEquivalent: ""
    )
    private let resetTextColorMenuItem = NSMenuItem(
        title: "Reset Text Color",
        action: #selector(resetTextColor),
        keyEquivalent: ""
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let savedColor = TextColorPreference.load() {
            coordinator.setTextColor(savedColor)
        }
        configureStatusItem()
        configureCallbacks()
        refreshLaunchAtLoginState()
        coordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.stop()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "quote.bubble",
                accessibilityDescription: "Touch Bar Lyrics"
            )
            button.toolTip = "Touch Bar Lyrics"
        }

        let menu = NSMenu()
        statusMenuItem.isEnabled = false
        versionMenuItem.isEnabled = false
        enabledMenuItem.target = self
        loginMenuItem.target = self
        textColorMenuItem.target = self
        resetTextColorMenuItem.target = self
        enabledMenuItem.state = .on

        menu.addItem(statusMenuItem)
        menu.addItem(versionMenuItem)
        menu.addItem(.separator())
        menu.addItem(enabledMenuItem)
        menu.addItem(textColorMenuItem)
        menu.addItem(resetTextColorMenuItem)
        menu.addItem(.separator())
        menu.addItem(loginMenuItem)
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Touch Bar Lyrics",
            action: #selector(quit),
            keyEquivalent: "q"
        ).target = self

        item.menu = menu
        statusItem = item
    }

    private func configureCallbacks() {
        coordinator.onStatusChange = { [weak self] status in
            self?.statusMenuItem.title = status
            self?.statusItem?.button?.toolTip = status
        }
        coordinator.onEnabledChange = { [weak self] enabled in
            self?.enabledMenuItem.state = enabled ? .on : .off
        }
    }

    @objc private func toggleLyrics() {
        coordinator.setEnabled(!coordinator.isEnabled)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            switch SMAppService.mainApp.status {
            case .enabled:
                try SMAppService.mainApp.unregister()
            default:
                try SMAppService.mainApp.register()
            }
        } catch {
            statusMenuItem.title = "Launch at Login failed: \(error.localizedDescription)"
        }
        refreshLaunchAtLoginState()
    }

    @objc private func chooseTextColor() {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.color = coordinator.textColor
        panel.setTarget(self)
        panel.setAction(#selector(textColorChanged))
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func textColorChanged() {
        let color = NSColorPanel.shared.color
        coordinator.setTextColor(color)
        TextColorPreference.save(color)
    }

    @objc private func resetTextColor() {
        let color = NSColor.labelColor
        coordinator.setTextColor(color)
        TextColorPreference.reset()
        if NSColorPanel.shared.isVisible {
            NSColorPanel.shared.color = color
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func refreshLaunchAtLoginState() {
        loginMenuItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}
