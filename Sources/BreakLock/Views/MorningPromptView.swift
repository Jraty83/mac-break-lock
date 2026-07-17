import SwiftUI

struct MorningPromptView: View {
    var onSetBreaks: () -> Void
    var onSkipToday: () -> Void
    var onVacation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L10n.t("prompt.morning.title"))
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.t("prompt.morning.subtitle"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button(action: onSetBreaks) {
                    Text(L10n.t("prompt.morning.set_times"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

                Button(action: onSkipToday) {
                    Text(L10n.t("prompt.morning.skip"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: onVacation) {
                    Text(L10n.t("prompt.morning.vacation"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

struct BreakTimesView: View {
    @State private var times: [Date]
    var onConfirm: ([Date]) -> Void
    var onCancel: () -> Void

    init(initial: [Date] = [Date()], onConfirm: @escaping ([Date]) -> Void, onCancel: @escaping () -> Void) {
        _times = State(initialValue: initial.isEmpty ? [Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()] : initial)
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.t("prompt.breaks.title"))
                .font(.title2.weight(.semibold))

            Text(L10n.t("prompt.breaks.subtitle"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(times.indices, id: \.self) { index in
                HStack {
                    Text(L10n.tf("prompt.breaks.item", index + 1))
                        .frame(width: 80, alignment: .leading)
                    DatePicker(
                        "",
                        selection: $times[index],
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    if times.count > 1 {
                        Button(role: .destructive) {
                            times.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .help(L10n.t("prompt.breaks.remove"))
                    }
                }
            }

            Button {
                let base = times.last ?? Date()
                let next = Calendar.current.date(byAdding: .hour, value: 1, to: base) ?? base
                times.append(next)
            } label: {
                Label(L10n.t("prompt.breaks.add"), systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            HStack {
                Button(L10n.t("prompt.breaks.cancel"), action: onCancel)
                Spacer()
                Button(L10n.t("prompt.breaks.confirm")) {
                    onConfirm(times)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(times.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

struct VacationModeView: View {
    @State private var until: Date
    var onConfirm: (Date) -> Void
    var onCancel: () -> Void

    init(onConfirm: @escaping (Date) -> Void, onCancel: @escaping () -> Void) {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        _until = State(initialValue: tomorrow)
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.t("prompt.vacation.title"))
                .font(.title2.weight(.semibold))

            Text(L10n.t("prompt.vacation.subtitle"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DatePicker(
                L10n.t("prompt.vacation.until"),
                selection: $until,
                in: Date()...,
                displayedComponents: .date
            )

            HStack {
                Button(L10n.t("prompt.vacation.cancel"), action: onCancel)
                Spacer()
                Button(L10n.t("prompt.vacation.confirm")) {
                    onConfirm(until)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}
