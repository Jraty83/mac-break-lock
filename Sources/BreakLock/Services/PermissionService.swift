import AppKit
import ApplicationServices
import Darwin
import Foundation
import UserNotifications

@MainActor
enum PermissionService {
    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Screen lock is ready when the system lock API works and/or Accessibility is granted.
    static var isScreenLockReady: Bool {
        ScreenLockService.hasSystemLockAPI || isAccessibilityTrusted
    }

    static func notificationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// System dialog that offers to open Privacy & Security → Accessibility.
    @discardableResult
    static func promptAccessibility() -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts = [key: kCFBooleanTrue] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    /// Opens System Settings → Privacy & Security → Accessibility
    /// (not the top-level Accessibility feature page with VoiceOver / Zoom).
    static func openAccessibilitySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ]
        for raw in urls {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    static func openNotificationSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ]
        for raw in urls {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    static var onboardingCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: "breaklock.onboardingCompleted") }
        set { UserDefaults.standard.set(newValue, forKey: "breaklock.onboardingCompleted") }
    }
}
