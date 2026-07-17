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
    @Published var shouldOpenPromptWindow = false
    @Published var permissionRefreshToken = 0

    private let scheduler = BreakScheduler.shared
    private var didStart = false

    func start() async {
        guard !didStart else { return }
        didStart = true

        NotificationService.shared.configure()
        scheduler.wireNotificationHandlers()
        scheduler.reload()
        await scheduler.rescheduleAll()
        refreshStatus()
        observeSessionEvents()

        // First install only — do not pop a window on every launch (Hot-style menu bar).
        // Missing Accessibility later is shown in the menu status; open Permissions from the menu.
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
        sheet = nil
        refreshStatus()
        evaluatePrompt()
    }

    func refreshStatus() {
        if !PermissionService.isAccessibilityTrusted {
            statusText = L10n.t("status.accessibility_missing")
            return
        }
        if scheduler.isOnVacation, let until = scheduler.state.vacationUntilDay {
            statusText = L10n.tf("status.vacation", until)
        } else if scheduler.promptedToday {
            let times = scheduler.state.breakTimes.filter { !scheduler.state.cancelledBreakIDs.contains($0) }
            statusText = times.isEmpty
                ? L10n.t("status.no_breaks_today")
                : L10n.tf("status.breaks", times.joined(separator: ", "))
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
        sheet = nil
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
            sheet = nil
            refreshStatus()
        }
    }

    func confirmVacation(_ day: Date) {
        scheduler.setVacation(until: day)
        sheet = nil
        refreshStatus()
    }

    func clearVacation() {
        scheduler.clearVacation()
        refreshStatus()
        evaluatePrompt()
    }

    private func observeSessionEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.scheduler.rescheduleAll()
                self?.evaluatePrompt()
            }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.evaluatePrompt()
            }
        }
    }
}
