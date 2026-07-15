@preconcurrency import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = PlaybackCoordinator()
    private var statusItem: NSStatusItem?
    private let statusMenuItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
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

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        enabledMenuItem.target = self
        loginMenuItem.target = self
        enabledMenuItem.state = .on

        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(enabledMenuItem)
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

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func refreshLaunchAtLoginState() {
        loginMenuItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}
