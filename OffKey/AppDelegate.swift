import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let blocker = KeyboardBlocker.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Убрать главное окно SwiftUI
        for window in NSApp.windows {
            window.close()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "keyboard",
                accessibilityDescription: "OffKey"
            )
            button.image?.isTemplate = true
        }

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

    @objc private func onKey() {
        blocker.stopBlocking()
    }

    @objc private func offKey() {
        if !blocker.startBlocking() {
            let alert = NSAlert()
            alert.messageText = "Нет доступа к мониторингу ввода"
            alert.informativeText = """
            Открой Системные настройки → Конфиденциальность и безопасность → Мониторинг ввода
            и включи OffKey, затем перезапусти приложение.
            """
            alert.runModal()
        }
    }

    @objc private func exitApp() {
        if blocker.isBlocked {
            blocker.stopBlocking()
        }
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
