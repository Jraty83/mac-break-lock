import Foundation

@MainActor
final class BreakScheduler {
    static let shared = BreakScheduler()

    private var lockTimers: [String: Timer] = [:]
    private(set) var state: BreakLockState = Persistence.load()

    enum BreakDisplayState {
        case past
        case next
        case upcoming
        case cancelled
    }

    struct BreakDisplayItem: Identifiable {
        let id: String
        let time: String
        let state: BreakDisplayState
    }

    func reload() {
        state = Persistence.load()
        rollToCurrentDayIfNeeded()
    }

    func save() {
        Persistence.save(state)
    }

    /// New calendar day → empty break list (morning starts clean).
    func rollToCurrentDayIfNeeded(now: Date = Date()) {
        let today = DayFormat.dayString(now)
        guard let last = state.lastPromptDay, last != today else { return }
        if !state.breakTimes.isEmpty {
            state.previousBreakTimes = state.breakTimes
        }
        state.breakTimes = []
        state.cancelledBreakIDs = []
        save()
        clearSchedules()
    }

    var hasPreviousBreaks: Bool {
        !state.previousBreakTimes.isEmpty
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

    /// All of today's breaks for the menu, with past / next / upcoming styling.
    func breakDisplayItems(now: Date = Date()) -> [BreakDisplayItem] {
        rollToCurrentDayIfNeeded(now: now)
        guard state.lastPromptDay == DayFormat.dayString(now) else { return [] }

        let sorted = state.breakTimes.sorted()
        let nextID = sorted.first { hhmm in
            guard !state.cancelledBreakIDs.contains(hhmm),
                  let date = DayFormat.parseTimeToday(hhmm, now: now) else { return false }
            return date > now
        }

        return sorted.map { hhmm in
            if state.cancelledBreakIDs.contains(hhmm) {
                return BreakDisplayItem(id: hhmm, time: hhmm, state: .cancelled)
            }
            guard let date = DayFormat.parseTimeToday(hhmm, now: now) else {
                return BreakDisplayItem(id: hhmm, time: hhmm, state: .past)
            }
            if date <= now {
                return BreakDisplayItem(id: hhmm, time: hhmm, state: .past)
            }
            if hhmm == nextID {
                return BreakDisplayItem(id: hhmm, time: hhmm, state: .next)
            }
            return BreakDisplayItem(id: hhmm, time: hhmm, state: .upcoming)
        }
    }

    static func isWeekday(_ date: Date = Date()) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday >= 2 && weekday <= 6
    }

    static func isAtOrAfterPromptHour(_ date: Date = Date(), hour: Int = 8) -> Bool {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        return h >= hour
    }

    func shouldShowMorningPrompt(now: Date = Date()) -> Bool {
        rollToCurrentDayIfNeeded(now: now)
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

    /// Clears today's breaks and cancels timers/notifications (keeps “prompted today”).
    func clearBreaks() {
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
        if !state.breakTimes.isEmpty {
            state.previousBreakTimes = state.breakTimes
        }
        state.cancelledBreakIDs = []
        save()
        await rescheduleAll()
    }

    /// Re-apply the last saved schedule onto today.
    @discardableResult
    func applyPreviousBreaks() async -> Bool {
        let source = state.previousBreakTimes
        guard !source.isEmpty else { return false }
        let dates = source.compactMap { DayFormat.parseTimeToday($0) }
        guard !dates.isEmpty else { return false }
        await confirmBreaks(dates)
        return true
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

    /// Tear down everything when quitting — no background locks after Quit.
    func shutdown() {
        clearSchedules()
    }

    func rescheduleAll() async {
        rollToCurrentDayIfNeeded()
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
        let fireDate = Calendar.current.date(
            bySettingHour: Calendar.current.component(.hour, from: breakDate),
            minute: Calendar.current.component(.minute, from: breakDate),
            second: 0,
            of: breakDate
        ) ?? breakDate

        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else {
            performLockIfNeeded(id: id)
            return
        }

        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.performLockIfNeeded(id: id)
            }
        }
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
