import AppKit
import Foundation
import ServiceManagement

enum LoginItemService {
    /// Registers BreakLock in System Settings → General → Login Items.
    @discardableResult
    static func registerAtLogin() -> Bool {
        do {
            try SMAppService.mainApp.register()
            NSLog("BreakLock: login item registered (%@)", String(describing: SMAppService.mainApp.status))
            return true
        } catch {
            NSLog("BreakLock: login item register failed: %@", error.localizedDescription)
            return false
        }
    }

    @discardableResult
    static func unregisterAtLogin() -> Bool {
        do {
            try SMAppService.mainApp.unregister()
            return true
        } catch {
            NSLog("BreakLock: login item unregister failed: %@", error.localizedDescription)
            return false
        }
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func openLoginItemsSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.users?LoginItems"
        ]
        for raw in urls {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
