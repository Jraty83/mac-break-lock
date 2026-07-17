import AppKit
import Darwin
import Foundation

@MainActor
enum ScreenLockService {
    @discardableResult
    static func lockScreen() -> Bool {
        if lockViaLoginFramework() {
            NSLog("BreakLock: locked via SACLockScreenImmediate")
            return true
        }

        if PermissionService.isAccessibilityTrusted, lockViaAppleScript() {
            NSLog("BreakLock: locked via AppleScript keystroke")
            return true
        }

        NSLog("BreakLock: all lock methods failed")
        return false
    }

    private static func lockViaLoginFramework() -> Bool {
        let candidates = [
            "/System/Library/PrivateFrameworks/login.framework/login",
            "/System/Library/PrivateFrameworks/login.framework/Versions/A/login",
            "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
        ]

        typealias LockFn = @convention(c) () -> Void

        for path in candidates {
            guard let handle = dlopen(path, RTLD_NOW) else { continue }
            defer { dlclose(handle) }
            guard let symbol = dlsym(handle, "SACLockScreenImmediate") else { continue }
            let lock = unsafeBitCast(symbol, to: LockFn.self)
            lock()
            return true
        }
        return false
    }

    private static func lockViaAppleScript() -> Bool {
        let source = """
        tell application "System Events" to keystroke "q" using {control down, command down}
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return false }
        _ = script.executeAndReturnError(&error)
        return error == nil
    }

    static func lockScreenOrExplain(openPermissions: @escaping () -> Void) {
        if lockScreen() { return }

        let alert = NSAlert()
        alert.messageText = L10n.t("alert.lock_failed.title")
        alert.informativeText = L10n.t("alert.lock_failed.body")
        alert.addButton(withTitle: L10n.t("alert.lock_failed.open"))
        alert.addButton(withTitle: L10n.t("alert.lock_failed.ok"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openPermissions()
        }
    }
}
