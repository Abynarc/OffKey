import AppKit
import ApplicationServices
import CoreGraphics

enum Permissions {
    static var hasInputMonitoring: Bool {
        CGPreflightListenEventAccess()
    }

    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    static var canBlockKeyboard: Bool {
        hasInputMonitoring && hasAccessibility
    }

    static func registerForInputMonitoring() {
        _ = CGRequestListenEventAccess()
    }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openInputMonitoringSettings() {
        openPrivacyPane("Privacy_ListenEvent")
    }

    static func openAccessibilitySettings() {
        openPrivacyPane("Privacy_Accessibility")
    }

    private static func openPrivacyPane(_ pane: String) {
        let urlString: String
        if #available(macOS 13, *) {
            urlString = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(pane)"
        } else {
            let legacyPane = pane == "Privacy_ListenEvent" ? "Privacy_ListenEvent" : "Privacy_Accessibility"
            urlString = "x-apple.systempreferences:com.apple.preference.security?\(legacyPane)"
        }

        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Запрашивает недостающие разрешения. Возвращает true, если оба уже выданы.
    @discardableResult
    static func promptForMissingPermissions() -> Bool {
        registerForInputMonitoring()

        let needsInputMonitoring = !hasInputMonitoring
        let needsAccessibility = !hasAccessibility

        guard needsInputMonitoring || needsAccessibility else {
            return true
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Отмена")

        if needsInputMonitoring && needsAccessibility {
            alert.messageText = "Нужны разрешения для блокировки клавиатуры"
            alert.informativeText = """
            OffKey нужен доступ к:
            • Мониторингу ввода
            • Универсальному доступу

            Нажми OK — откроются настройки. Включи OffKey в обоих разделах, \
            затем снова выбери Off Key.
            """
        } else if needsInputMonitoring {
            alert.messageText = "Нужен мониторинг ввода"
            alert.informativeText = "Включи OffKey в «Мониторинге ввода», затем снова выбери Off Key."
        } else {
            alert.messageText = "Нужен Универсальный доступ"
            alert.informativeText = "Включи OffKey в «Универсальном доступе», затем снова выбери Off Key."
        }

        guard alert.runModal() == .alertFirstButtonReturn else {
            return false
        }

        if needsInputMonitoring {
            openInputMonitoringSettings()
        }
        if needsAccessibility {
            requestAccessibility()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                openAccessibilitySettings()
            }
        }

        return false
    }
}
