import XCTest
@testable import GPSGymCore

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// 2026-10-26 is a Monday.
private func date(_ day: Int, hour: Int = 12) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
}

private func profile(
    goal: FitnessGoal = .buildMuscle,
    experience: Experience = .intermediate,
    equipment: Equipment = .fullGym,
    days: Set<Weekday> = [.monday, .tuesday, .thursday, .friday],
    minutes: Int = 60
) -> TrainingProfile {
    TrainingProfile(goal: goal, experience: experience, equipment: equipment, mode: .gym, trainingDays: days, sessionMinutes: minutes)
}

final class WorkoutGeneratorTests: XCTestCase {
    func testFourDayIntermediateGetsUpperLower() {
        let plan = WorkoutGenerator.generate(for: profile())
        XCTAssertEqual(plan.days.map(\.id), ["upper-a", "lower-a", "upper-b", "lower-b"])
        XCTAssertEqual(plan.schedule.map(\.weekday), [.monday, .tuesday, .thursday, .friday])
        XCTAssertEqual(plan.trainingWeekdays.count, 4)
    }

    func testBeginnerAlwaysGetsFullBody() {
        let plan = WorkoutGenerator.generate(for: profile(experience: .beginner))
        XCTAssertTrue(plan.days.allSatisfy { $0.id.hasPrefix("full-") })
        // 4 days rotate through 3 full-body workouts.
        XCTAssertEqual(plan.schedule.map(\.workoutDayID), ["full-a", "full-b", "full-c", "full-a"])
    }

    func testSixDaysIsPushPullLegs() {
        let days: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let plan = WorkoutGenerator.generate(for: profile(days: days))
        XCTAssertEqual(plan.days.map(\.id), ["push", "pull", "legs"])
        XCTAssertEqual(plan.schedule.count, 6)
    }

    func testEveryEquipmentTierProducesWorkoutsWithOnlyAvailableGear() {
        for equipment in Equipment.allCases {
            for goal in FitnessGoal.allCases {
                let plan = WorkoutGenerator.generate(for: profile(goal: goal, equipment: equipment))
                for day in plan.days {
                    XCTAssertGreaterThanOrEqual(day.exercises.count, 3, "\(equipment) \(goal) \(day.id)")
                    XCTAssertTrue(day.exercises.allSatisfy { equipment.available.contains($0.exercise.equipment) })
                    XCTAssertEqual(Set(day.exercises.map(\.id)).count, day.exercises.count, "duplicate exercise in \(day.id)")
                }
            }
        }
    }

    func testSessionsFitTimeBudgetWhenPossible() {
        for minutes in TrainingProfile.sessionLengthOptions {
            for goal in FitnessGoal.allCases {
                let plan = WorkoutGenerator.generate(for: profile(goal: goal, experience: .advanced, minutes: minutes))
                for day in plan.days where day.exercises.count > 3 {
                    XCTAssertLessThanOrEqual(day.estimatedMinutes, minutes, "\(goal) \(minutes)min \(day.id)")
                }
            }
        }
    }

    func testStrengthUsesLowerRepsAndLongerRestThanFatLoss() {
        let strength = WorkoutGenerator.generate(for: profile(goal: .getStronger)).days[0].exercises[0]
        let fatLoss = WorkoutGenerator.generate(for: profile(goal: .loseFat)).days[0].exercises[0]
        XCTAssertLessThan(strength.repsHigh, fatLoss.repsHigh)
        XCTAssertGreaterThan(strength.restSeconds, fatLoss.restSeconds)
    }
}

final class ProgressionTests: XCTestCase {
    private let bench = PlannedExercise(
        exercise: ExerciseLibrary.exercise(id: "bench-press")!, role: .primary,
        sets: 3, repsLow: 6, repsHigh: 8, restSeconds: 120
    )

    func testNoHistory() {
        XCTAssertEqual(Progression.suggest(for: bench, history: []).kind, .firstTime)
    }

    func testIncreaseWhenTopOfRangeOnAllSets() {
        let last = Array(repeating: LoggedSet(weight: 135, reps: 8), count: 3)
        let suggestion = Progression.suggest(for: bench, history: [last])
        XCTAssertEqual(suggestion.kind, .increase)
        XCTAssertEqual(suggestion.weight, 140)
    }

    func testRepeatWhenInRange() {
        let last = [LoggedSet(weight: 135, reps: 8), LoggedSet(weight: 135, reps: 7), LoggedSet(weight: 135, reps: 6)]
        XCTAssertEqual(Progression.suggest(for: bench, history: [last]).kind, .repeatWeight)
    }

    func testDeloadAfterTwoMissedSessions() {
        let missed = [LoggedSet(weight: 135, reps: 5), LoggedSet(weight: 135, reps: 4)]
        let suggestion = Progression.suggest(for: bench, history: [missed, missed])
        XCTAssertEqual(suggestion.kind, .deload)
        XCTAssertEqual(suggestion.weight, 120) // 121.5 rounded to nearest 5
    }

    func testEstimatedOneRepMax() {
        XCTAssertEqual(Progression.estimatedOneRepMax(LoggedSet(weight: 100, reps: 1)), 100)
        XCTAssertEqual(Progression.estimatedOneRepMax(LoggedSet(weight: 150, reps: 10))!, 200, accuracy: 0.001)
        XCTAssertNil(Progression.estimatedOneRepMax(LoggedSet(weight: nil, reps: 10)))
    }
}

final class VerificationTests: XCTestCase {
    private let policy = VerificationPolicy.standard(plannedMinutes: 60) // 36 min minimum

    private func evidence(minutes: Double, sets: Int, mode: WorkoutMode = .gym, samples: [LocationSample]) -> SessionEvidence {
        SessionEvidence(
            startedAt: date(26), endedAt: date(26).addingTimeInterval(minutes * 60),
            plannedSets: 20, completedSets: sets, mode: mode, locationSamples: samples
        )
    }

    private func sample(_ distance: Double, accuracy: Double = 20) -> LocationSample {
        LocationSample(date: date(26), distanceMeters: distance, accuracyMeters: accuracy)
    }

    func testStandardPolicyFloor() {
        XCTAssertEqual(VerificationPolicy.standard(plannedMinutes: 30).minimumMinutes, 20)
        XCTAssertEqual(policy.minimumMinutes, 36)
    }

    func testVerifiedAtGym() {
        let result = Verifier.evaluate(evidence(minutes: 45, sets: 15, samples: [sample(30), sample(80)]), policy: policy)
        XCTAssertTrue(result.isVerified)
        XCTAssertEqual(result.location, .atGym)
        XCTAssertEqual(result.trust, .high)
    }

    func testTooShortAndTooFewSets() {
        let result = Verifier.evaluate(evidence(minutes: 10, sets: 3, samples: [sample(30)]), policy: policy)
        XCTAssertFalse(result.isVerified)
        XCTAssertFalse(result.durationMet)
        XCTAssertFalse(result.setsMet)
        XCTAssertEqual(result.unmetReasons.count, 2)
    }

    func testAwayFromGymFails() {
        let result = Verifier.evaluate(evidence(minutes: 45, sets: 15, samples: [sample(2_000), sample(1_800)]), policy: policy)
        XCTAssertFalse(result.isVerified)
        XCTAssertEqual(result.location, .awayFromGym)
    }

    func testAccuracyGivesBenefitOfDoubt() {
        // 250m away but ±120m accuracy → could be inside a 150m radius.
        XCTAssertEqual(Verifier.locationStatus([sample(250, accuracy: 120)], mode: .gym, policy: policy), .atGym)
    }

    func testNoSignalPassesWithLowTrust() {
        let result = Verifier.evaluate(evidence(minutes: 45, sets: 15, samples: [sample(5_000, accuracy: 1_500)]), policy: policy)
        XCTAssertTrue(result.isVerified)
        XCTAssertEqual(result.location, .noSignal)
        XCTAssertEqual(result.trust, .low)
    }

    func testHomeModeSkipsLocation() {
        let result = Verifier.evaluate(evidence(minutes: 40, sets: 12, mode: .home, samples: []), policy: policy)
        XCTAssertTrue(result.isVerified)
        XCTAssertEqual(result.location, .notRequired)
    }
}

final class EnforcementTests: XCTestCase {
    private func state(start: Int = 26) -> EnforcementState {
        EnforcementState(
            trainingWeekdays: [.monday, .wednesday, .friday],
            enforcementStartDay: DayKey.make(date(start), calendar: utc)
        )
    }

    func testDayKey() {
        XCTAssertEqual(DayKey.make(date(30), calendar: utc), "2026-10-30")
    }

    func testLockedOnTrainingDayUntilCompleted() {
        var s = state()
        XCTAssertTrue(s.shouldShield(on: date(26), calendar: utc))           // Monday
        XCTAssertEqual(s.status(on: date(27), calendar: utc), .restDay)      // Tuesday
        s.completedDays.insert("2026-10-26")
        XCTAssertEqual(s.status(on: date(26), calendar: utc), .unlockedByWorkout)
    }

    func testNotEnforcedBeforeStartOrWhenPaused() {
        var s = state(start: 28)
        XCTAssertEqual(s.status(on: date(26), calendar: utc), .notEnforced)
        XCTAssertTrue(s.shouldShield(on: date(28), calendar: utc))
        s.isPaused = true
        XCTAssertFalse(s.shouldShield(on: date(28), calendar: utc))
    }

    func testOneRestSwapPerWeek() {
        var s = state()
        XCTAssertTrue(s.canSwapRestDay(on: date(26), calendar: utc))
        XCTAssertFalse(s.canSwapRestDay(on: date(27), calendar: utc)) // not a training day
        s.restDaySwaps.insert("2026-10-26")
        XCTAssertEqual(s.status(on: date(26), calendar: utc), .unlockedByRestSwap)
        XCTAssertFalse(s.canSwapRestDay(on: date(28), calendar: utc))
        // Next week resets.
        let nextMonday = utc.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12))!
        XCTAssertTrue(s.canSwapRestDay(on: nextMonday, calendar: utc))
    }

    func testStreak() {
        var s = state(start: 19)
        s.completedDays = ["2026-10-19", "2026-10-21", "2026-10-23", "2026-10-26", "2026-10-28"]
        // Friday the 30th not done yet — doesn't break the streak.
        XCTAssertEqual(s.currentStreak(asOf: date(30), calendar: utc), 5)
        // Missed Friday → next Monday streak is 0.
        let monday = utc.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12))!
        XCTAssertEqual(s.currentStreak(asOf: monday, calendar: utc), 0)
        // A rest swap on Friday is neutral.
        s.restDaySwaps.insert("2026-10-30")
        XCTAssertEqual(s.currentStreak(asOf: monday, calendar: utc), 5)
        // An emergency unlock breaks it.
        s.restDaySwaps = []
        s.emergencyUnlocks.insert("2026-10-30")
        XCTAssertEqual(s.currentStreak(asOf: monday, calendar: utc), 0)
    }

    func testWeeklyAdherence() {
        var s = state()
        s.completedDays = ["2026-10-26", "2026-10-28"]
        let adherence = s.weeklyAdherence(containing: date(30), calendar: utc)
        XCTAssertEqual(adherence.completed, 2)
        XCTAssertEqual(adherence.scheduled, 3)
    }
}
