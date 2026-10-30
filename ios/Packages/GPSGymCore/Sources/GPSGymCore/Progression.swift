import Foundation

public struct LoggedSet: Codable, Hashable, Sendable {
    public var weight: Double?
    public var reps: Int

    public init(weight: Double?, reps: Int) {
        self.weight = weight
        self.reps = reps
    }
}

public struct ProgressionSuggestion: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case firstTime, increase, repeatWeight, deload, addReps
    }

    public var kind: Kind
    /// Suggested working weight in lb, nil for bodyweight or no history.
    public var weight: Double?
    public var message: String
}

/// Double progression: hit the top of the range on every set → add load.
public enum Progression {
    /// - Parameter history: completed sets per previous session, most recent first.
    public static func suggest(for planned: PlannedExercise, history: [[LoggedSet]]) -> ProgressionSuggestion {
        guard let last = history.first, !last.isEmpty else {
            let message = planned.exercise.isBodyweight
                ? "Aim for \(planned.repsLow)–\(planned.repsHigh) clean reps."
                : "Pick a weight you can lift for \(planned.repsHigh) reps with 1–3 left in the tank."
            return .init(kind: .firstTime, weight: nil, message: message)
        }

        let lastWeight = last.compactMap(\.weight).max()
        let hitTop = last.count >= planned.sets && last.allSatisfy { $0.reps >= planned.repsHigh }
        let missedBottom: ([LoggedSet]) -> Bool = { session in session.contains { $0.reps < planned.repsLow } }
        let missedTwice = history.count >= 2 && missedBottom(history[0]) && missedBottom(history[1])

        if planned.exercise.isBodyweight || lastWeight == nil {
            return hitTop
                ? .init(kind: .addReps, weight: nil, message: "You maxed the range — slow the lowering to 3s or use a harder variation.")
                : .init(kind: .repeatWeight, weight: nil, message: "Beat last time by at least one rep.")
        }

        let weight = lastWeight!
        if hitTop {
            let next = weight + planned.exercise.loadIncrementLb
            return .init(kind: .increase, weight: next, message: "Top of the range on every set. Go \(format(next)) lb.")
        }
        if missedTwice {
            let next = roundToNearest(weight * 0.9, step: 5)
            return .init(kind: .deload, weight: next, message: "Two tough sessions — reset to \(format(next)) lb and build back.")
        }
        return .init(kind: .repeatWeight, weight: weight, message: "Stay at \(format(weight)) lb and add reps.")
    }

    /// Best estimated one-rep max (Epley) — a simple, monotonic progress signal.
    public static func estimatedOneRepMax(_ set: LoggedSet) -> Double? {
        guard let weight = set.weight, weight > 0, set.reps > 0 else { return nil }
        return set.reps == 1 ? weight : weight * (1 + Double(set.reps) / 30)
    }

    static func roundToNearest(_ value: Double, step: Double) -> Double {
        (value / step).rounded() * step
    }

    public static func format(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(weight)) : String(format: "%.1f", weight)
    }
}
