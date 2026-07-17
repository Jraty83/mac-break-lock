import Foundation

struct BreakLockState: Codable, Equatable {
    /// Calendar day (yyyy-MM-dd) when the morning prompt was last handled.
    var lastPromptDay: String?
    /// Break times for today as "HH:mm" in local time.
    var breakTimes: [String]
    /// Break identifiers cancelled via "Ei taukoa".
    var cancelledBreakIDs: [String]
    /// Inclusive end date (yyyy-MM-dd) for vacation mute. Nil = not on vacation.
    var vacationUntilDay: String?

    static let empty = BreakLockState(
        lastPromptDay: nil,
        breakTimes: [],
        cancelledBreakIDs: [],
        vacationUntilDay: nil
    )
}

enum DayFormat {
    static let day: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "fi_FI")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let time: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f
    }()

    static func dayString(_ date: Date = Date()) -> String {
        day.string(from: date)
    }

    static func timeString(_ date: Date) -> String {
        time.string(from: date)
    }

    static func parseDay(_ string: String) -> Date? {
        day.date(from: string)
    }

    static func parseTimeToday(_ hhmm: String, now: Date = Date()) -> Date? {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: now
        )
    }
}
