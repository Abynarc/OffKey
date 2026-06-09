import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let blocker = KeyboardBlocker.shared
    private var awaitingPermissions = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        for window in NSApp.windows {
            window.close()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusIcon(blocked: false)

        let menu = NSMenu()

        let onItem = NSMenuItem(title: "On Key", action: #selector(onKey), keyEquivalent: "")
        onItem.target = self
        menu.addItem(onItem)

        let offItem = NSMenuItem(title: "Off Key", action: #selector(offKey), keyEquivalent: "")
        offItem.target = self
        menu.addItem(offItem)

        menu.addItem(.separator())

        let exitItem = NSMenuItem(title: "Exit", action: #selector(exitApp), keyEquivalent: "q")
        exitItem.target = self
        menu.addItem(exitItem)

        statusItem.menu = menu
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard awaitingPermissions else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.retryAfterPermissions()
        }
    }

    private func updateStatusIcon(blocked: Bool) {
        guard let button = statusItem.button else { return }

        let symbolName = blocked ? "keyboard.fill" : "keyboard"
        button.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "OffKey"
        )
        button.image?.isTemplate = true
    }

    @objc private func onKey() {
        awaitingPermissions = false
        blocker.stopBlocking()
        updateStatusIcon(blocked: false)
    }

    @objc private func offKey() {
        if blocker.isBlocked {
            return
        }

        if tryEnableBlocking() {
            return
        }

        guard !awaitingPermissions else { return }

        awaitingPermissions = true
        _ = Permissions.promptForMissingPermissions()
    }

    private func tryEnableBlocking() -> Bool {
        guard Permissions.canBlockKeyboard else {
            return false
        }

        if blocker.startBlocking() {
            awaitingPermissions = false
            updateStatusIcon(blocked: true)
            return true
        }

        return false
    }

    private func retryAfterPermissions() {
        guard awaitingPermissions else { return }

        if tryEnableBlocking() {
            return
        }

        if Permissions.canBlockKeyboard {
            awaitingPermissions = false
        }
    }

    @objc private func exitApp() {
        awaitingPermissions = false
        if blocker.isBlocked {
            blocker.stopBlocking()
            updateStatusIcon(blocked: false)
        }
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
