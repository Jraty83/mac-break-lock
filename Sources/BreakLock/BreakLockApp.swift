import AppKit
import SwiftUI

@main
struct BreakLockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra(L10n.t("app.name"), systemImage: "cup.and.saucer.fill") {
            MenuContent(model: model)
        }

        Window(L10n.t("app.name"), id: "prompt") {
            PromptRootView(model: model)
                .task {
                    appDelegate.model = model
                    await model.start()
                }
                .onChange(of: model.shouldOpenPromptWindow) { _, open in
                    guard open else { return }
                    NSApp.activate(ignoringOtherApps: true)
                    model.shouldOpenPromptWindow = false
                }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultLaunchBehavior(.presented)
    }
}

private struct MenuContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.statusText)
                .font(.headline)
                .padding(.bottom, 4)

            Button(L10n.t("menu.permissions")) {
                model.presentPermissions()
                openWindow(id: "prompt")
            }

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

            Button(L10n.t("menu.reschedule")) {
                Task {
                    BreakScheduler.shared.reload()
                    await BreakScheduler.shared.rescheduleAll()
                    model.refreshStatus()
                }
            }

            Divider()

            Button(L10n.t("menu.quit")) {
                NSApp.terminate(nil)
            }
        }
        .padding(8)
        .frame(minWidth: 240)
        .onChange(of: model.shouldOpenPromptWindow) { _, open in
            guard open else { return }
            openWindow(id: "prompt")
            NSApp.activate(ignoringOtherApps: true)
            model.shouldOpenPromptWindow = false
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
                VStack(spacing: 12) {
                    Text(L10n.t("idle.title"))
                        .font(.title2.weight(.semibold))
                    Text(model.statusText)
                        .foregroundStyle(.secondary)
                    Button(L10n.t("idle.open_permissions")) {
                        model.presentPermissions()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .frame(width: 380, height: 180)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model?.presentPermissions()
        return true
    }
}
