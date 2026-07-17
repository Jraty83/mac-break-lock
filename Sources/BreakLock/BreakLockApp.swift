import AppKit
import SwiftUI

@main
struct BreakLockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: appDelegate.model)
        } label: {
            MenuBarLabel(model: appDelegate.model)
        }

        Window(L10n.t("app.name"), id: "prompt") {
            PromptRootView(model: appDelegate.model)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "cup.and.saucer.fill")
            .onChange(of: model.shouldOpenPromptWindow) { _, open in
                guard open else { return }
                openWindow(id: "prompt")
                NSApp.activate(ignoringOtherApps: true)
                model.shouldOpenPromptWindow = false
            }
            .onChange(of: model.shouldClosePromptWindow) { _, close in
                guard close else { return }
                closePromptWindows()
                model.shouldClosePromptWindow = false
            }
    }
}

@MainActor
private func closePromptWindows() {
    for window in NSApp.windows {
        let id = window.identifier?.rawValue ?? ""
        if id == "prompt" || window.title == L10n.t("app.name") {
            window.close()
        }
    }
}

private struct MenuContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BreakStatusHeader(model: model)
                .padding(.bottom, 4)

            Button(L10n.t("menu.open_morning_prompt")) {
                model.openMorningPromptManually()
                openWindow(id: "prompt")
            }

            if BreakScheduler.shared.isOnVacation {
                Button(L10n.t("menu.clear_vacation")) {
                    model.clearVacation()
                }
            }

            Divider()

            Button(L10n.t("menu.lock_now")) {
                ScreenLockService.lockScreenOrExplain {
                    model.presentPermissions()
                    openWindow(id: "prompt")
                }
            }

            Button(L10n.t("menu.clear_breaks")) {
                model.clearBreaks()
            }

            Button(L10n.t("menu.reschedule")) {
                model.forceReschedule()
            }

            Button(L10n.t("menu.permissions")) {
                model.presentPermissions()
                openWindow(id: "prompt")
            }

            Divider()

            Button(L10n.t("menu.quit")) {
                model.quit()
            }
        }
        .padding(8)
        .frame(minWidth: 240)
        .onAppear {
            model.refreshStatus()
        }
    }
}

private struct BreakStatusHeader: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if !PermissionService.isScreenLockReady || BreakScheduler.shared.isOnVacation || model.breakItems.isEmpty {
            Text(model.statusText)
                .font(.headline)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(L10n.t("status.breaks_prefix"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                ForEach(Array(model.breakItems.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Text(", ")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Text(item.time)
                        .font(.headline)
                        .fontWeight(item.state == .next ? .bold : .regular)
                        .foregroundStyle(style(for: item.state))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func style(for state: BreakScheduler.BreakDisplayState) -> AnyShapeStyle {
        switch state {
        case .past, .cancelled:
            AnyShapeStyle(.tertiary)
        case .next:
            AnyShapeStyle(.primary)
        case .upcoming:
            AnyShapeStyle(.secondary)
        }
    }
}

private struct PromptRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            switch model.sheet {
            case .permissions:
                PermissionsOnboardingView(model: model)
            case .morning:
                MorningPromptView(
                    onSetBreaks: { model.openBreakEditor() },
                    onSkipToday: { model.skipToday() },
                    onVacation: { model.openVacationEditor() }
                )
            case .breaks:
                BreakTimesView(
                    onConfirm: { model.confirmBreaks($0) },
                    onCancel: { model.sheet = .morning }
                )
            case .vacation:
                VacationModeView(
                    onConfirm: { model.confirmVacation($0) },
                    onCancel: { model.sheet = .morning }
                )
            case nil:
                Color.clear
                    .frame(width: 1, height: 1)
                    .onAppear {
                        closePromptWindows()
                    }
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Task { await model.start() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cancel timers + pending notifications so Quit never locks later in the background.
        BreakScheduler.shared.shutdown()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !PermissionService.onboardingCompleted {
            model.presentPermissions()
        } else {
            model.openMorningPromptManually()
        }
        return true
    }
}
