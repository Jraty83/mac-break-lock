import SwiftUI
import UserNotifications

struct PermissionsOnboardingView: View {
    @ObservedObject var model: AppModel
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var screenLockReady = false
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.t("onboarding.title"))
                .font(.title2.weight(.semibold))

            Text(L10n.t("onboarding.subtitle"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            permissionRow(
                title: L10n.t("onboarding.notifications.title"),
                detail: L10n.t("onboarding.notifications.detail"),
                granted: notificationsGranted,
                primaryTitle: L10n.t("onboarding.allow"),
                primary: {
                    Task { await model.requestNotificationsFromOnboarding() }
                },
                secondaryTitle: L10n.t("onboarding.open_settings"),
                secondary: {
                    PermissionService.openNotificationSettings()
                }
            )

            permissionRow(
                title: L10n.t("onboarding.lock.title"),
                detail: L10n.t("onboarding.lock.detail"),
                granted: screenLockReady,
                primaryTitle: L10n.t("onboarding.allow"),
                primary: {
                    model.requestAccessibilityFromOnboarding()
                },
                secondaryTitle: L10n.t("onboarding.open_accessibility"),
                secondary: {
                    PermissionService.openAccessibilitySettings()
                }
            )

            if !screenLockReady {
                Text(L10n.t("onboarding.lock.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button(L10n.t("onboarding.recheck")) {
                    refreshStatuses()
                }
                Spacer()
                Button(continueTitle) {
                    model.finishOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            refreshStatuses()
            startPolling()
        }
        .onDisappear {
            pollTask?.cancel()
        }
        .onChange(of: model.permissionRefreshToken) { _, _ in
            refreshStatuses()
        }
    }

    private var notificationsGranted: Bool {
        notificationStatus == .authorized || notificationStatus == .provisional
    }

    private var continueTitle: String {
        if notificationsGranted && screenLockReady {
            L10n.t("onboarding.done")
        } else {
            L10n.t("onboarding.continue_partial")
        }
    }

    private func permissionRow(
        title: String,
        detail: String,
        granted: Bool,
        primaryTitle: String,
        primary: @escaping () -> Void,
        secondaryTitle: String,
        secondary: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(granted ? .green : .secondary)
                Text(title)
                    .font(.headline)
                Spacer()
                Text(granted ? L10n.t("onboarding.status.granted") : L10n.t("onboarding.status.missing"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(granted ? .green : .orange)
            }
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !granted {
                HStack {
                    Button(primaryTitle, action: primary)
                        .buttonStyle(.borderedProminent)
                    Button(secondaryTitle, action: secondary)
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private func refreshStatuses() {
        screenLockReady = PermissionService.isScreenLockReady
        Task {
            notificationStatus = await PermissionService.notificationStatus()
            // If everything needed works, don't keep nagging — mark onboarding done.
            if notificationsGranted && screenLockReady && !PermissionService.onboardingCompleted {
                await MainActor.run {
                    model.finishOnboarding()
                }
            }
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run { refreshStatuses() }
            }
        }
    }
}
