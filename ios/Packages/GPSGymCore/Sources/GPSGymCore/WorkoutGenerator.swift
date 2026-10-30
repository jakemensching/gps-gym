import Foundation

/// Deterministic, template-based program generator.
///
/// Why not an LLM for the MVP: it's free, instant, offline, testable, and can't
/// hallucinate an unsafe program. Templates encode standard splits; the profile
/// tunes split choice, exercise selection, volume, rep ranges, rest and length.
public enum WorkoutGenerator {
    struct Slot {
        let pattern: MovementPattern
        let role: SlotRole
        /// Which candidate to prefer, so "Upper B" doesn't repeat "Upper A" exactly.
        var variant: Int = 0
    }

    struct DayTemplate {
        let id: String
        let name: String
        let focus: String
        let slots: [Slot]
    }

    // MARK: Templates

    static let fullBodyA = DayTemplate(id: "full-a", name: "Full Body A", focus: "Squat, press, row", slots: [
        Slot(pattern: .squat, role: .primary),
        Slot(pattern: .horizontalPush, role: .primary),
        Slot(pattern: .horizontalPull, role: .secondary),
        Slot(pattern: .hinge, role: .secondary, variant: 1),
        Slot(pattern: .biceps, role: .accessory),
        Slot(pattern: .core, role: .accessory),
    ])
    static let fullBodyB = DayTemplate(id: "full-b", name: "Full Body B", focus: "Hinge, overhead, pull", slots: [
        Slot(pattern: .hinge, role: .primary),
        Slot(pattern: .verticalPush, role: .primary),
        Slot(pattern: .verticalPull, role: .secondary),
        Slot(pattern: .lunge, role: .secondary),
        Slot(pattern: .triceps, role: .accessory),
        Slot(pattern: .calves, role: .accessory),
    ])
    static let fullBodyC = DayTemplate(id: "full-c", name: "Full Body C", focus: "Legs, incline, back", slots: [
        Slot(pattern: .squat, role: .primary, variant: 1),
        Slot(pattern: .horizontalPush, role: .secondary, variant: 1),
        Slot(pattern: .horizontalPull, role: .secondary, variant: 1),
        Slot(pattern: .hinge, role: .secondary, variant: 2),
        Slot(pattern: .shoulderIsolation, role: .accessory),
        Slot(pattern: .core, role: .accessory, variant: 1),
    ])
    static let upperA = DayTemplate(id: "upper-a", name: "Upper A", focus: "Horizontal push & pull", slots: [
        Slot(pattern: .horizontalPush, role: .primary),
        Slot(pattern: .horizontalPull, role: .primary),
        Slot(pattern: .verticalPush, role: .secondary),
        Slot(pattern: .verticalPull, role: .secondary),
        Slot(pattern: .biceps, role: .accessory),
        Slot(pattern: .triceps, role: .accessory),
    ])
    static let upperB = DayTemplate(id: "upper-b", name: "Upper B", focus: "Vertical push & pull", slots: [
        Slot(pattern: .verticalPush, role: .primary),
        Slot(pattern: .verticalPull, role: .primary),
        Slot(pattern: .horizontalPush, role: .secondary, variant: 1),
        Slot(pattern: .horizontalPull, role: .secondary, variant: 1),
        Slot(pattern: .shoulderIsolation, role: .accessory),
        Slot(pattern: .biceps, role: .accessory, variant: 1),
    ])
    static let lowerA = DayTemplate(id: "lower-a", name: "Lower A", focus: "Squat focus", slots: [
        Slot(pattern: .squat, role: .primary),
        Slot(pattern: .hinge, role: .secondary, variant: 1),
        Slot(pattern: .lunge, role: .secondary),
        Slot(pattern: .calves, role: .accessory),
        Slot(pattern: .core, role: .accessory),
    ])
    static let lowerB = DayTemplate(id: "lower-b", name: "Lower B", focus: "Hinge focus", slots: [
        Slot(pattern: .hinge, role: .primary),
        Slot(pattern: .squat, role: .secondary, variant: 1),
        Slot(pattern: .lunge, role: .secondary, variant: 1),
        Slot(pattern: .calves, role: .accessory),
        Slot(pattern: .core, role: .accessory, variant: 1),
    ])
    static let push = DayTemplate(id: "push", name: "Push", focus: "Chest, shoulders, triceps", slots: [
        Slot(pattern: .horizontalPush, role: .primary),
        Slot(pattern: .verticalPush, role: .secondary),
        Slot(pattern: .horizontalPush, role: .secondary, variant: 1),
        Slot(pattern: .shoulderIsolation, role: .accessory),
        Slot(pattern: .triceps, role: .accessory),
    ])
    static let pull = DayTemplate(id: "pull", name: "Pull", focus: "Back, rear delts, biceps", slots: [
        Slot(pattern: .verticalPull, role: .primary),
        Slot(pattern: .horizontalPull, role: .secondary),
        Slot(pattern: .horizontalPull, role: .secondary, variant: 1),
        Slot(pattern: .shoulderIsolation, role: .accessory, variant: 1),
        Slot(pattern: .biceps, role: .accessory),
    ])
    static let legs = DayTemplate(id: "legs", name: "Legs", focus: "Quads, hamstrings, glutes", slots: [
        Slot(pattern: .squat, role: .primary),
        Slot(pattern: .hinge, role: .secondary, variant: 1),
        Slot(pattern: .lunge, role: .secondary),
        Slot(pattern: .calves, role: .accessory),
        Slot(pattern: .core, role: .accessory),
    ])

    /// Rotation of workouts across the user's training days.
    static func split(dayCount: Int, experience: Experience) -> (name: String, rotation: [DayTemplate]) {
        // Beginners progress fastest on frequent full-body practice of the main lifts.
        if experience == .beginner || dayCount <= 3 {
            let rotation = [fullBodyA, fullBodyB, fullBodyC]
            return ("Full Body", Array(rotation.prefix(max(1, min(dayCount, 3)))))
        }
        switch dayCount {
        case 4: return ("Upper / Lower", [upperA, lowerA, upperB, lowerB])
        case 5: return ("Upper / Lower + Push / Pull / Legs", [upperA, lowerA, push, pull, legs])
        default: return ("Push / Pull / Legs", [push, pull, legs])
        }
    }

    // MARK: Prescription

    struct Prescription {
        var sets: Int
        var repsLow: Int
        var repsHigh: Int
        var restSeconds: Int
    }

    /// With several goals, the most strength-leaning one drives the main lifts, the most
    /// conditioning-leaning one drives accessories, and the middle one drives secondaries.
    public static func goal(for role: SlotRole, goals: Set<FitnessGoal>) -> FitnessGoal {
        let sorted = FitnessGoal.priority.filter(goals.contains)
        guard let first = sorted.first, let last = sorted.last else { return .buildMuscle }
        switch role {
        case .primary: return first
        case .accessory: return last
        case .secondary: return sorted[(sorted.count - 1) / 2]
        }
    }

    static func prescription(goals: Set<FitnessGoal>, role: SlotRole, experience: Experience) -> Prescription {
        var p: Prescription
        switch (goal(for: role, goals: goals), role) {
        case (.getStronger, .primary): p = .init(sets: 4, repsLow: 3, repsHigh: 5, restSeconds: 180)
        case (.getStronger, .secondary): p = .init(sets: 3, repsLow: 6, repsHigh: 8, restSeconds: 120)
        case (.getStronger, .accessory): p = .init(sets: 2, repsLow: 8, repsHigh: 12, restSeconds: 75)
        case (.buildMuscle, .primary): p = .init(sets: 4, repsLow: 6, repsHigh: 8, restSeconds: 150)
        case (.buildMuscle, .secondary): p = .init(sets: 3, repsLow: 8, repsHigh: 12, restSeconds: 90)
        case (.buildMuscle, .accessory): p = .init(sets: 3, repsLow: 10, repsHigh: 15, restSeconds: 60)
        case (.generalFitness, .primary): p = .init(sets: 3, repsLow: 8, repsHigh: 10, restSeconds: 90)
        case (.generalFitness, .secondary): p = .init(sets: 3, repsLow: 10, repsHigh: 12, restSeconds: 75)
        case (.generalFitness, .accessory): p = .init(sets: 2, repsLow: 12, repsHigh: 15, restSeconds: 60)
        case (.loseFat, .primary): p = .init(sets: 3, repsLow: 8, repsHigh: 12, restSeconds: 75)
        case (.loseFat, .secondary): p = .init(sets: 3, repsLow: 10, repsHigh: 15, restSeconds: 60)
        case (.loseFat, .accessory): p = .init(sets: 2, repsLow: 12, repsHigh: 15, restSeconds: 45)
        }
        switch experience {
        case .beginner where role != .accessory: p.sets = max(2, p.sets - 1)
        case .advanced where role == .primary: p.sets += 1
        default: break
        }
        return p
    }

    // MARK: Generation

    public static func generate(for profile: TrainingProfile, now: Date = Date()) -> TrainingPlan {
        let weekdays = profile.trainingDays.sorted()
        let (splitName, rotation) = split(dayCount: weekdays.count, experience: profile.experience)
        let days = rotation.map { buildDay($0, profile: profile) }

        let schedule = weekdays.enumerated().map { index, weekday in
            ScheduledDay(weekday: weekday, workoutDayID: days[index % days.count].id)
        }

        return TrainingPlan(
            name: "\(weekdays.count)-Day \(splitName)",
            days: days,
            schedule: schedule,
            progressionNotes: progressionNotes(for: profile),
            createdAt: now
        )
    }

    static func buildDay(_ template: DayTemplate, profile: TrainingProfile) -> WorkoutDay {
        var used = Set<String>()
        var exercises: [PlannedExercise] = []

        for slot in template.slots {
            let candidates = ExerciseLibrary.candidates(for: slot.pattern, equipment: profile.equipment)
                .filter { !used.contains($0.id) && !profile.avoidExerciseIDs.contains($0.id) }
            guard !candidates.isEmpty else { continue }
            let exercise = candidates[slot.variant % candidates.count]
            used.insert(exercise.id)

            var p = prescription(goals: profile.goals, role: slot.role, experience: profile.experience)
            if profile.focusPatterns.contains(slot.pattern) { p.sets += 1 }
            if exercise.isBodyweight {
                // Bodyweight work needs higher reps to be a meaningful stimulus.
                p.repsLow = max(p.repsLow, 8)
                p.repsHigh = max(p.repsHigh, 15)
            }
            exercises.append(PlannedExercise(
                exercise: exercise, role: slot.role, sets: p.sets,
                repsLow: p.repsLow, repsHigh: p.repsHigh, restSeconds: p.restSeconds
            ))
        }

        return WorkoutDay(
            id: template.id,
            name: template.name,
            focus: template.focus,
            exercises: fit(exercises, toMinutes: profile.sessionMinutes)
        )
    }

    /// Trim volume until the session fits the user's time budget.
    /// Order: drop accessories → trim secondary sets → drop secondaries (keep ≥ 3 exercises).
    static func fit(_ input: [PlannedExercise], toMinutes budget: Int) -> [PlannedExercise] {
        var exercises = input
        while estimateMinutes(exercises) > budget,
              let index = exercises.lastIndex(where: { $0.role == .accessory }) {
            exercises.remove(at: index)
        }
        while estimateMinutes(exercises) > budget,
              let index = exercises.lastIndex(where: { $0.role == .secondary && $0.sets > 2 }) {
            exercises[index].sets -= 1
        }
        while estimateMinutes(exercises) > budget, exercises.count > 3,
              let index = exercises.lastIndex(where: { $0.role == .secondary }) {
            exercises.remove(at: index)
        }
        return exercises
    }

    static let warmupMinutes = 5
    static let secondsPerSet = 45

    public static func estimateMinutes(_ exercises: [PlannedExercise]) -> Int {
        let seconds = exercises.reduce(0) { total, item in
            total + item.sets * secondsPerSet + max(0, item.sets - 1) * item.restSeconds + 60 // +60s setup/transition
        }
        return warmupMinutes + Int((Double(seconds) / 60).rounded(.up))
    }

    static func progressionNotes(for profile: TrainingProfile) -> [String] {
        var notes = [
            "Double progression: once you hit the top of the rep range on every set, add the smallest available weight next session.",
            "If you fall below the bottom of the rep range two sessions in a row, drop the weight ~10% and build back up.",
            "Leave 1–3 reps in the tank on most sets. Form first — stop a set when technique breaks down.",
            "Every 6–8 weeks, or when you feel run down, take a lighter week with half the sets.",
        ]
        if profile.equipment == .bodyweight {
            notes.append("Bodyweight moves: progress by adding reps, slowing the lowering phase to 3 seconds, or switching to the harder variation.")
        }
        if profile.goals.contains(.loseFat) {
            notes.append("Lifting helps preserve muscle; fat loss is driven mostly by nutrition and daily activity.")
        }
        if let coachNote = profile.coachNote, !coachNote.isEmpty { notes.insert(coachNote, at: 0) }
        notes.append("This is a general program, not medical advice. Results vary — stop and consult a professional if anything hurts.")
        return notes
    }
}
