import Foundation

@MainActor
final class BreakScheduler {
    static let shared = BreakScheduler()

    private var lockTimers: [String: Timer] = [:]
    private(set) var state: BreakLockState = Persistence.load()

    func reload() {
        state = Persistence.load()
    }

    func save() {
        Persistence.save(state)
    }

    var isOnVacation: Bool {
        guard let until = state.vacationUntilDay,
              let end = DayFormat.parseDay(until) else { return false }
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
        return Date() <= endOfDay
    }

    var promptedToday: Bool {
        state.lastPromptDay == DayFormat.dayString()
    }

    static func isWeekday(_ date: Date = Date()) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        // 1 = Sunday ... 7 = Saturday
        return weekday >= 2 && weekday <= 6
    }

    static func isAtOrAfterPromptHour(_ date: Date = Date(), hour: Int = 8) -> Bool {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        return h >= hour
    }

    func shouldShowMorningPrompt(now: Date = Date()) -> Bool {
        guard Self.isWeekday(now) else { return false }
        guard Self.isAtOrAfterPromptHour(now) else { return false }
        guard !isOnVacation else { return false }
        guard !promptedToday else { return false }
        return true
    }

    func skipToday() {
        state.lastPromptDay = DayFormat.dayString()
        state.breakTimes = []
        state.cancelledBreakIDs = []
        save()
        clearSchedules()
    }

    func setVacation(until day: Date) {
        state.vacationUntilDay = DayFormat.dayString(day)
        state.lastPromptDay = DayFormat.dayString()
        state.breakTimes = []
        state.cancelledBreakIDs = []
        save()
        clearSchedules()
    }

    func clearVacation() {
        state.vacationUntilDay = nil
        save()
    }

    func confirmBreaks(_ times: [Date]) async {
        let sorted = times.sorted()
        state.lastPromptDay = DayFormat.dayString()
        state.breakTimes = sorted.map { DayFormat.timeString($0) }
        state.cancelledBreakIDs = []
        save()
        await rescheduleAll()
    }

    func cancelBreak(id: String) {
        if !state.cancelledBreakIDs.contains(id) {
            state.cancelledBreakIDs.append(id)
            save()
        }
        NotificationService.shared.cancelBreak(id: id)
        lockTimers[id]?.invalidate()
        lockTimers[id] = nil
    }

    func clearSchedules() {
        NotificationService.shared.cancelAllBreakNotifications()
        for timer in lockTimers.values { timer.invalidate() }
        lockTimers.removeAll()
    }

    func rescheduleAll() async {
        clearSchedules()
        guard !isOnVacation else { return }
        guard state.lastPromptDay == DayFormat.dayString() else { return }

        let now = Date()
        for hhmm in state.breakTimes {
            guard let breakDate = DayFormat.parseTimeToday(hhmm, now: now) else { continue }
            let id = hhmm
            if state.cancelledBreakIDs.contains(id) { continue }
            if breakDate <= now { continue }

            await NotificationService.shared.scheduleBreakWarning(id: id, breakDate: breakDate)
            scheduleLocalLockTimer(id: id, breakDate: breakDate)
        }
    }

    private func scheduleLocalLockTimer(id: String, breakDate: Date) {
        lockTimers[id]?.invalidate()
        // Fire at the start of that minute so "10:00" locks when the clock hits 10:00.
        let fireDate = Calendar.current.date(
            bySettingHour: Calendar.current.component(.hour, from: breakDate),
            minute: Calendar.current.component(.minute, from: breakDate),
            second: 0,
            of: breakDate
        ) ?? breakDate

        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else {
            // Exact minute already reached while confirming — lock immediately.
            performLockIfNeeded(id: id)
            return
        }

        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.performLockIfNeeded(id: id)
            }
        }
        // .common keeps the timer alive while the menu / tracking run-loop modes are active.
        RunLoop.main.add(timer, forMode: .common)
        lockTimers[id] = timer
        NSLog("BreakLock: scheduled lock %@ in %.1fs", id, interval)
    }

    func performLockIfNeeded(id: String) {
        guard !state.cancelledBreakIDs.contains(id) else { return }
        NSLog("BreakLock: locking for break %@", id)
        let ok = ScreenLockService.lockScreen()
        if !ok {
            NSLog("BreakLock: lock failed for %@", id)
        }
        NotificationService.shared.cancelBreak(id: id)
        lockTimers[id]?.invalidate()
        lockTimers[id] = nil
    }

    func wireNotificationHandlers() {
        NotificationService.shared.onCancelBreak = { [weak self] id in
            self?.cancelBreak(id: id)
        }
    }
}
