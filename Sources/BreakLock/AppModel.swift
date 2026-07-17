import AppKit
import Combine
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    enum Sheet: Identifiable, Equatable {
        case permissions
        case morning
        case breaks
        case vacation

        var id: String {
            switch self {
            case .permissions: "permissions"
            case .morning: "morning"
            case .breaks: "breaks"
            case .vacation: "vacation"
            }
        }
    }

    @Published var sheet: Sheet?
    @Published var statusText: String = L10n.t("status.starting")
    @Published var breakItems: [BreakScheduler.BreakDisplayItem] = []
    @Published var shouldOpenPromptWindow = false
    @Published var shouldClosePromptWindow = false
    @Published var permissionRefreshToken = 0

    private let scheduler = BreakScheduler.shared
    private var didStart = false

    func start() async {
        guard !didStart else { return }
        didStart = true

        NotificationService.shared.configure()
        scheduler.wireNotificationHandlers()
        _ = LoginItemService.registerAtLogin()
        scheduler.reload()
        await scheduler.rescheduleAll()
        refreshStatus()
        observeSessionEvents()

        if !PermissionService.onboardingCompleted {
            presentPermissions()
        } else {
            evaluatePrompt()
        }
    }

    func presentPermissions() {
        sheet = .permissions
        shouldOpenPromptWindow = true
        permissionRefreshToken += 1
    }

    func requestNotificationsFromOnboarding() async {
        _ = await NotificationService.shared.requestAuthorization()
        permissionRefreshToken += 1
    }

    func requestAccessibilityFromOnboarding() {
        _ = PermissionService.promptAccessibility()
        PermissionService.openAccessibilitySettings()
        permissionRefreshToken += 1
    }

    func finishOnboarding() {
        PermissionService.onboardingCompleted = true
        dismissPromptWindow()
        refreshStatus()
        evaluatePrompt()
    }

    func dismissPromptWindow() {
        sheet = nil
        shouldClosePromptWindow = true
    }

    func refreshStatus() {
        scheduler.rollToCurrentDayIfNeeded()
        breakItems = scheduler.breakDisplayItems()

        if !PermissionService.isScreenLockReady {
            statusText = L10n.t("status.accessibility_missing")
            return
        }
        if scheduler.isOnVacation, let until = scheduler.state.vacationUntilDay {
            statusText = L10n.tf("status.vacation", until)
        } else if scheduler.promptedToday {
            statusText = breakItems.isEmpty
                ? L10n.t("status.no_breaks_today")
                : L10n.t("status.breaks_prefix")
        } else {
            statusText = L10n.t("status.waiting_prompt")
        }
    }

    func evaluatePrompt() {
        guard scheduler.shouldShowMorningPrompt() else { return }
        presentMorning()
    }

    func openMorningPromptManually() {
        presentMorning()
    }

    private func presentMorning() {
        sheet = .morning
        shouldOpenPromptWindow = true
    }

    func skipToday() {
        scheduler.skipToday()
        dismissPromptWindow()
        refreshStatus()
    }

    func openBreakEditor() {
        sheet = .breaks
    }

    func openVacationEditor() {
        sheet = .vacation
    }

    func confirmBreaks(_ times: [Date]) {
        Task {
            await scheduler.confirmBreaks(times)
            dismissPromptWindow()
            refreshStatus()
        }
    }

    func confirmVacation(_ day: Date) {
        scheduler.setVacation(until: day)
        dismissPromptWindow()
        refreshStatus()
    }

    func clearVacation() {
        scheduler.clearVacation()
        refreshStatus()
        evaluatePrompt()
    }

    func clearBreaks() {
        scheduler.clearBreaks()
        refreshStatus()
    }

    func forceReschedule() {
        Task {
            scheduler.reload()
            await scheduler.rescheduleAll()
            refreshStatus()
        }
    }

    func quit() {
        scheduler.shutdown()
        NSApp.terminate(nil)
    }

    private func observeSessionEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduler.rollToCurrentDayIfNeeded()
                await self?.scheduler.rescheduleAll()
                self?.refreshStatus()
                self?.evaluatePrompt()
            }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduler.rollToCurrentDayIfNeeded()
                self?.refreshStatus()
                self?.evaluatePrompt()
            }
        }
    }
}
