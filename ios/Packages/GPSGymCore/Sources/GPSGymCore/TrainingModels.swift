import Foundation

public enum FitnessGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case buildMuscle, getStronger, generalFitness, loseFat

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .buildMuscle: return "Build muscle"
        case .getStronger: return "Get stronger"
        case .generalFitness: return "General fitness"
        case .loseFat: return "Lose fat"
        }
    }
}

public enum Experience: String, Codable, CaseIterable, Identifiable, Sendable {
    case beginner, intermediate, advanced

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    public var subtitle: String {
        switch self {
        case .beginner: return "Under 6 months of consistent lifting"
        case .intermediate: return "6 months – 2 years"
        case .advanced: return "2+ years, comfortable with barbell lifts"
        }
    }
}

public enum Equipment: String, Codable, CaseIterable, Identifiable, Sendable {
    case fullGym, dumbbells, bodyweight

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fullGym: return "Full gym"
        case .dumbbells: return "Dumbbells only"
        case .bodyweight: return "Bodyweight only"
        }
    }

    /// Equipment tiers are cumulative: a full gym also has dumbbells and floor space.
    public var available: Set<Equipment> {
        switch self {
        case .fullGym: return [.fullGym, .dumbbells, .bodyweight]
        case .dumbbells: return [.dumbbells, .bodyweight]
        case .bodyweight: return [.bodyweight]
        }
    }
}

public enum WorkoutMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Location-verified at a saved gym.
    case gym
    /// No location check; verified by duration and logging only.
    case home

    public var id: String { rawValue }
    public var title: String { self == .gym ? "At a gym" : "At home" }
}

/// Matches `Calendar.component(.weekday, ...)`: Sunday = 1 ... Saturday = 7.
public enum Weekday: Int, Codable, CaseIterable, Identifiable, Comparable, Sendable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public var id: Int { rawValue }

    public var shortName: String {
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][rawValue - 1]
    }

    public var initial: String {
        ["S", "M", "T", "W", "T", "F", "S"][rawValue - 1]
    }

    /// Monday-first ordering, which is how most lifters think about a training week.
    public static var mondayFirst: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }

    public var mondayFirstIndex: Int { (rawValue + 5) % 7 }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.mondayFirstIndex < rhs.mondayFirstIndex
    }

    public init(date: Date, calendar: Calendar = .current) {
        self = Weekday(rawValue: calendar.component(.weekday, from: date)) ?? .monday
    }
}

/// Everything onboarding collects that affects the program.
public struct TrainingProfile: Codable, Equatable, Sendable {
    public var goal: FitnessGoal
    public var experience: Experience
    public var equipment: Equipment
    public var mode: WorkoutMode
    public var trainingDays: Set<Weekday>
    public var sessionMinutes: Int

    public init(
        goal: FitnessGoal,
        experience: Experience,
        equipment: Equipment,
        mode: WorkoutMode,
        trainingDays: Set<Weekday>,
        sessionMinutes: Int
    ) {
        self.goal = goal
        self.experience = experience
        self.equipment = equipment
        self.mode = mode
        self.trainingDays = trainingDays
        self.sessionMinutes = sessionMinutes
    }

    /// At least one rest day is required, so the max is 6.
    public static let maxTrainingDays = 6
    public static let sessionLengthOptions = [30, 45, 60, 75, 90]
}

public enum MovementPattern: String, Codable, Sendable {
    case squat, hinge, lunge
    case horizontalPush, verticalPush, horizontalPull, verticalPull
    case shoulderIsolation, biceps, triceps, calves, core
}

public struct Exercise: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let pattern: MovementPattern
    public let equipment: Equipment
    public let isCompound: Bool
    /// Smallest sensible load jump in pounds. 0 means bodyweight: progress with reps.
    public let loadIncrementLb: Double

    public var isBodyweight: Bool { loadIncrementLb == 0 }
}

public enum SlotRole: String, Codable, Sendable {
    case primary, secondary, accessory
}

public struct PlannedExercise: Codable, Hashable, Identifiable, Sendable {
    public var exercise: Exercise
    public var role: SlotRole
    public var sets: Int
    public var repsLow: Int
    public var repsHigh: Int
    public var restSeconds: Int

    public var id: String { exercise.id }

    public var prescription: String {
        repsLow == repsHigh ? "\(sets) × \(repsLow)" : "\(sets) × \(repsLow)–\(repsHigh)"
    }
}

public struct WorkoutDay: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var focus: String
    public var exercises: [PlannedExercise]

    public var totalSets: Int { exercises.reduce(0) { $0 + $1.sets } }
    public var estimatedMinutes: Int { WorkoutGenerator.estimateMinutes(exercises) }
}

public struct ScheduledDay: Codable, Hashable, Sendable {
    public var weekday: Weekday
    public var workoutDayID: String
}

public struct TrainingPlan: Codable, Equatable, Sendable {
    public var name: String
    public var days: [WorkoutDay]
    public var schedule: [ScheduledDay]
    public var progressionNotes: [String]
    public var createdAt: Date

    public func workoutDay(for weekday: Weekday) -> WorkoutDay? {
        guard let id = schedule.first(where: { $0.weekday == weekday })?.workoutDayID else { return nil }
        return days.first { $0.id == id }
    }

    public var trainingWeekdays: Set<Weekday> { Set(schedule.map(\.weekday)) }
}
