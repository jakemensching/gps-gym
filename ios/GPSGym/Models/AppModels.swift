import Foundation
import GPSGymCore

struct GymLocation: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
}

/// Everything onboarding produced. Stored locally only — gym coordinates never leave the device.
struct UserSetup: Codable, Equatable {
    var profile: TrainingProfile
    var plan: TrainingPlan
    var gym: GymLocation?
    var createdAt: Date
}

struct SetEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var weight: Double?
    var reps: Int
    var isDone = false
}

struct ExerciseLog: Codable, Identifiable, Equatable {
    var planned: PlannedExercise
    var sets: [SetEntry]

    var id: String { planned.id }
    var completedSets: [SetEntry] { sets.filter(\.isDone) }
}

/// In-progress workout. Persisted on every change so a crash or force-quit
/// doesn't lose the session (the timer is derived from `startedAt`).
struct ActiveWorkoutDraft: Codable, Equatable {
    var id = UUID()
    var day: WorkoutDay
    var mode: WorkoutMode
    var startedAt: Date
    var dayKey: String
    var exercises: [ExerciseLog]
    var locationSamples: [LocationSample] = []
    var restEndsAt: Date?

    var plannedSets: Int { exercises.reduce(0) { $0 + $1.planned.sets } }
    var completedSets: Int { exercises.reduce(0) { $0 + $1.completedSets.count } }

    var policy: VerificationPolicy { .standard(plannedMinutes: day.estimatedMinutes) }

    func evidence(endingAt end: Date) -> SessionEvidence {
        SessionEvidence(
            startedAt: startedAt, endedAt: end,
            plannedSets: plannedSets, completedSets: completedSets,
            mode: mode, locationSamples: locationSamples
        )
    }
}

struct WorkoutRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var workoutDayID: String
    var workoutName: String
    var dayKey: String
    var startedAt: Date
    var endedAt: Date
    var mode: WorkoutMode
    var plannedSets: Int
    var exercises: [ExerciseLog]
    var isVerified: Bool
    var locationStatus: LocationStatus
    var trust: TrustLevel

    var completedSets: Int { exercises.reduce(0) { $0 + $1.completedSets.count } }
    var durationMinutes: Int { Int(endedAt.timeIntervalSince(startedAt) / 60) }
    var totalVolume: Double {
        exercises.flatMap(\.completedSets).reduce(0) { $0 + ($1.weight ?? 0) * Double($1.reps) }
    }
}

struct FinishedWorkout: Identifiable {
    let record: WorkoutRecord
    let result: VerificationResult
    let unlockedApps: Bool

    var id: UUID { record.id }
}
