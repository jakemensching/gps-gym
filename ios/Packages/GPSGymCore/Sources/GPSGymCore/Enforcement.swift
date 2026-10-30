import Foundation

/// Stable local-calendar day identifier ("2026-10-30"). Shared between the app
/// and the DeviceActivity extension through the App Group.
public enum DayKey {
    public static func make(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

public enum DayStatus: Equatable, Sendable {
    /// Not a scheduled training day — apps are open.
    case restDay
    /// Enforcement hasn't started yet, or is paused.
    case notEnforced
    /// Training day, workout not yet verified — apps are shielded.
    case locked
    case unlockedByWorkout
    case unlockedByRestSwap
    case unlockedByEmergency

    public var isLocked: Bool { self == .locked }
}

/// The single source of truth for "should distracting apps be blocked right now?".
/// Pure value type so the extension and the app make the exact same decision.
public struct EnforcementState: Codable, Equatable, Sendable {
    public var trainingWeekdays: Set<Weekday>
    /// First day enforcement applies (DayKey). nil = blocking not set up.
    public var enforcementStartDay: String?
    public var isPaused: Bool
    public var completedDays: Set<String>
    /// User-declared recovery days (sick, sore, travel). Limited to one per week.
    public var restDaySwaps: Set<String>
    /// Always-available safety override. Unlimited, but logged and breaks the streak.
    public var emergencyUnlocks: Set<String>

    public init(
        trainingWeekdays: Set<Weekday> = [],
        enforcementStartDay: String? = nil,
        isPaused: Bool = false,
        completedDays: Set<String> = [],
        restDaySwaps: Set<String> = [],
        emergencyUnlocks: Set<String> = []
    ) {
        self.trainingWeekdays = trainingWeekdays
        self.enforcementStartDay = enforcementStartDay
        self.isPaused = isPaused
        self.completedDays = completedDays
        self.restDaySwaps = restDaySwaps
        self.emergencyUnlocks = emergencyUnlocks
    }

    public func status(on date: Date, calendar: Calendar = .current) -> DayStatus {
        let key = DayKey.make(date, calendar: calendar)
        guard trainingWeekdays.contains(Weekday(date: date, calendar: calendar)) else { return .restDay }
        if completedDays.contains(key) { return .unlockedByWorkout }
        if restDaySwaps.contains(key) { return .unlockedByRestSwap }
        if emergencyUnlocks.contains(key) { return .unlockedByEmergency }
        // DayKey strings sort chronologically, so string comparison is safe.
        guard !isPaused, let start = enforcementStartDay, key >= start else { return .notEnforced }
        return .locked
    }

    public func shouldShield(on date: Date, calendar: Calendar = .current) -> Bool {
        status(on: date, calendar: calendar).isLocked
    }

    public func canSwapRestDay(on date: Date, calendar: Calendar = .current) -> Bool {
        guard trainingWeekdays.contains(Weekday(date: date, calendar: calendar)) else { return false }
        let week = WeekWindow(containing: date, calendar: calendar)
        return !restDaySwaps.contains { week.contains(key: $0) }
    }

    // MARK: Stats

    /// Consecutive scheduled training days completed. Today doesn't break the
    /// streak until it's over; rest-day swaps are neutral; emergency unlocks break it.
    public func currentStreak(asOf date: Date, calendar: Calendar = .current) -> Int {
        var streak = 0
        var day = calendar.startOfDay(for: date)
        let today = day
        for _ in 0..<400 {
            let key = DayKey.make(day, calendar: calendar)
            if trainingWeekdays.contains(Weekday(date: day, calendar: calendar)) {
                if completedDays.contains(key) {
                    streak += 1
                } else if restDaySwaps.contains(key) || day == today {
                    // neutral
                } else {
                    break
                }
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    /// Completed vs scheduled sessions in the Monday–Sunday week containing `date`.
    public func weeklyAdherence(containing date: Date, calendar: Calendar = .current) -> (completed: Int, scheduled: Int) {
        let week = WeekWindow(containing: date, calendar: calendar)
        let scheduled = week.days.filter {
            trainingWeekdays.contains(Weekday(date: $0, calendar: calendar))
                && !restDaySwaps.contains(DayKey.make($0, calendar: calendar))
        }.count
        let completed = week.days.filter { completedDays.contains(DayKey.make($0, calendar: calendar)) }.count
        return (min(completed, scheduled), scheduled)
    }
}

/// Monday–Sunday week.
public struct WeekWindow: Sendable {
    public let days: [Date]
    private let keys: Set<String>

    public init(containing date: Date, calendar: Calendar = .current) {
        let start = calendar.startOfDay(for: date)
        let offset = Weekday(date: start, calendar: calendar).mondayFirstIndex
        let monday = calendar.date(byAdding: .day, value: -offset, to: start) ?? start
        days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
        keys = Set(days.map { DayKey.make($0, calendar: calendar) })
    }

    public func contains(key: String) -> Bool { keys.contains(key) }
}
