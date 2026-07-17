import Foundation
import UserNotifications

enum NotificationIDs {
    static let categoryWarning = "BREAK_WARNING"
    static let actionCancel = "CANCEL_BREAK"
    static let warningPrefix = "break-warning-"
}

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    var onCancelBreak: ((String) -> Void)?

    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let cancel = UNNotificationAction(
            identifier: NotificationIDs.actionCancel,
            title: L10n.t("notify.action.no_break"),
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: NotificationIDs.categoryWarning,
            actions: [cancel],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            NSLog("BreakLock: notification auth failed: %@", error.localizedDescription)
            return false
        }
    }

    func cancelAllBreakNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    func cancelBreak(id: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            NotificationIDs.warningPrefix + id
        ])
        center.removeDeliveredNotifications(withIdentifiers: [
            NotificationIDs.warningPrefix + id
        ])
    }

    func scheduleBreakWarning(id: String, breakDate: Date) async {
        let center = UNUserNotificationCenter.current()
        cancelBreak(id: id)

        let warningDate = breakDate.addingTimeInterval(-5 * 60)
        let now = Date()
        guard warningDate > now else { return }

        let content = UNMutableNotificationContent()
        content.title = L10n.t("notify.warning.title")
        content.body = L10n.t("notify.warning.body")
        content.sound = .default
        content.categoryIdentifier = NotificationIDs.categoryWarning
        content.userInfo = ["breakID": id]
        content.threadIdentifier = "breaks"
        content.interruptionLevel = .timeSensitive

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: warningDate
            ),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: NotificationIDs.warningPrefix + id,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let breakID = info["breakID"] as? String ?? ""

        if response.actionIdentifier == NotificationIDs.actionCancel {
            await MainActor.run {
                onCancelBreak?(breakID)
            }
        }
    }
}
