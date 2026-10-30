import FamilyControls
import Foundation
import GPSGymCore
import Observation

/// App-wide state and the only place that mutates persisted data.
@MainActor
@Observable
final class AppModel {
    private enum File {
        static let setup = "setup.json"
        static let workouts = "workouts.json"
        static let activeWorkout = "activeWorkout.json"
    }

    private(set) var setup: UserSetup?
    private(set) var workouts: [WorkoutRecord] = []
    private(set) var enforcement = EnforcementState()
    private(set) var selection = FamilyActivitySelection()
    private(set) var isScreenTimeAuthorized = false
    private(set) var lastError: String?

    var activeWorkout: ActiveWorkoutDraft? {
        didSet { LocalStore.save(activeWorkout, to: File.activeWorkout) }
    }

    /// Set after a workout is saved; drives the result sheet.
    var lastFinished: FinishedWorkout?

    let location = LocationService()

    init() {
        setup = LocalStore.load(UserSetup.self, from: File.setup)
        workouts = LocalStore.load([WorkoutRecord].self, from: File.workouts) ?? []
        activeWorkout = LocalStore.load(ActiveWorkoutDraft.self, from: File.activeWorkout)
        enforcement = SharedStore.loadEnforcement()
        selection = SharedStore.loadSelection()
        isScreenTimeAuthorized = ScreenTimeService.isAuthorized
    }

    // MARK: Derived

    var isOnboarded: Bool { setup != nil }
    var plan: TrainingPlan? { setup?.plan }

    var todayStatus: DayStatus { enforcement.status(on: Date()) }
    var todayWorkout: WorkoutDay? { plan?.workoutDay(for: Weekday(date: Date())) }

    /// Next scheduled workout after today, for rest-day screens.
    var nextWorkout: (weekday: Weekday, day: WorkoutDay)? {
        guard let plan else { return nil }
        let today = Weekday(date: Date())
        for offset in 1...7 {
            let weekday = Weekday(rawValue: (today.rawValue - 1 + offset) % 7 + 1)!
            if let day = plan.workoutDay(for: weekday) { return (weekday, day) }
        }
        return nil
    }

    var currentStreak: Int { enforcement.currentStreak(asOf: Date()) }
    var thisWeek: (completed: Int, scheduled: Int) { enforcement.weeklyAdherence(containing: Date()) }
    var hasSelectedApps: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
    }

    /// Previous sessions' completed sets for an exercise, most recent first.
    func history(for exerciseID: String, limit: Int = 5) -> [[LoggedSet]] {
        workouts
            .sorted { $0.startedAt > $1.startedAt }
            .compactMap { record in
                record.exercises.first { $0.planned.exercise.id == exerciseID }?
                    .completedSets.map { LoggedSet(weight: $0.weight, reps: $0.reps) }
            }
            .filter { !$0.isEmpty }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: Lifecycle

    /// Call on launch and every time the app becomes active.
    func refresh() {
        isScreenTimeAuthorized = ScreenTimeService.isAuthorized
        enforcement = SharedStore.loadEnforcement()
        guard isOnboarded, isScreenTimeAuthorized else { return }
        // Belt and braces: the extension should already have done this at midnight.
        ShieldController.sync()
        if !ScreenTimeService.monitoredActivities.contains(.daily) {
            startMonitoring()
        }
    }

    func requestScreenTimeAuthorization() async {
        do {
            try await ScreenTimeService.requestAuthorization()
            lastError = nil
        } catch {
            lastError = "Screen Time permission wasn't granted. You can try again in Settings. (\(error.localizedDescription))"
        }
        isScreenTimeAuthorized = ScreenTimeService.isAuthorized
        if isScreenTimeAuthorized && isOnboarded {
            startMonitoring()
            ShieldController.sync()
        }
    }

    // MARK: Onboarding & settings

    func completeOnboarding(profile: TrainingProfile, gym: GymLocation?, selection: FamilyActivitySelection, enforceToday: Bool) {
        let plan = WorkoutGenerator.generate(for: profile)
        setup = UserSetup(profile: profile, plan: plan, gym: gym, createdAt: Date())
        LocalStore.save(setup, to: File.setup)

        let start = enforceToday ? Date() : Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        updateEnforcement {
            $0.trainingWeekdays = plan.trainingWeekdays
            $0.enforcementStartDay = DayKey.make(start)
            $0.isPaused = false
        }
        updateSelection(selection)
        startMonitoring()
    }

    func updateSelection(_ newSelection: FamilyActivitySelection) {
        selection = newSelection
        SharedStore.saveSelection(newSelection)
        ShieldController.sync()
    }

    func updateProfile(_ profile: TrainingProfile) {
        guard var setup else { return }
        setup.profile = profile
        setup.plan = WorkoutGenerator.generate(for: profile)
        self.setup = setup
        LocalStore.save(setup, to: File.setup)
        updateEnforcement { $0.trainingWeekdays = setup.plan.trainingWeekdays }
    }

    func updateGym(_ gym: GymLocation?) {
        guard var setup else { return }
        setup.gym = gym
        self.setup = setup
        LocalStore.save(setup, to: File.setup)
    }

    func setPaused(_ paused: Bool) {
        updateEnforcement { $0.isPaused = paused }
    }

    // MARK: Safety valves

    var canSwapRestDayToday: Bool { enforcement.canSwapRestDay(on: Date()) && todayStatus == .locked }

    func swapRestDayToday() {
        guard canSwapRestDayToday else { return }
        updateEnforcement { $0.restDaySwaps.insert(DayKey.make(Date())) }
    }

    /// Always available. Logged, breaks the streak, never blocked behind anything.
    func emergencyUnlockToday() {
        updateEnforcement { $0.emergencyUnlocks.insert(DayKey.make(Date())) }
    }

    // MARK: Workouts

    func startWorkout(_ day: WorkoutDay) {
        guard let setup else { return }
        let exercises = day.exercises.map { planned in
            let suggestion = Progression.suggest(for: planned, history: history(for: planned.exercise.id))
            let sets = (0..<planned.sets).map { _ in
                SetEntry(weight: suggestion.weight, reps: planned.repsHigh)
            }
            return ExerciseLog(planned: planned, sets: sets)
        }
        // No saved gym → can only verify as a home workout.
        let mode: WorkoutMode = setup.gym == nil ? .home : setup.profile.mode
        activeWorkout = ActiveWorkoutDraft(
            day: day, mode: mode, startedAt: Date(), dayKey: DayKey.make(Date()), exercises: exercises
        )
    }

    func recordLocationSample() async {
        guard let draft = activeWorkout, draft.mode == .gym, let gym = setup?.gym else { return }
        guard let sample = await location.sample(distanceTo: gym) else { return }
        // The draft may have been finished or discarded while we waited.
        guard activeWorkout?.id == draft.id else { return }
        activeWorkout?.locationSamples.append(sample)
    }

    /// Check requirements without saving, so the user can keep training if short.
    func previewVerification(at end: Date = Date()) -> VerificationResult? {
        guard let draft = activeWorkout else { return nil }
        return Verifier.evaluate(draft.evidence(endingAt: end), policy: draft.policy)
    }

    /// Saves the session. Verified workouts unlock the apps for the day they started.
    @discardableResult
    func finishWorkout(at end: Date = Date()) -> VerificationResult? {
        guard let draft = activeWorkout else { return nil }
        let result = Verifier.evaluate(draft.evidence(endingAt: end), policy: draft.policy)
        let record = WorkoutRecord(
            id: draft.id, workoutDayID: draft.day.id, workoutName: draft.day.name, dayKey: draft.dayKey,
            startedAt: draft.startedAt, endedAt: end, mode: draft.mode, plannedSets: draft.plannedSets,
            exercises: draft.exercises, isVerified: result.isVerified,
            locationStatus: result.location, trust: result.trust
        )
        workouts.append(record)
        LocalStore.save(workouts, to: File.workouts)
        let wasLocked = enforcement.status(on: draft.startedAt) == .locked
        if result.isVerified {
            updateEnforcement { $0.completedDays.insert(draft.dayKey) }
        }
        activeWorkout = nil
        let finished = FinishedWorkout(record: record, result: result, unlockedApps: result.isVerified && wasLocked)
        // Let the full-screen workout cover finish dismissing before presenting the result sheet.
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            lastFinished = finished
        }
        return result
    }

    func discardWorkout() {
        activeWorkout = nil
    }

    // MARK: Reset

    func resetEverything() {
        ShieldController.clear()
        ScreenTimeService.stopAllMonitoring()
        SharedStore.clearAll()
        LocalStore.deleteAll()
        setup = nil
        workouts = []
        activeWorkout = nil
        enforcement = EnforcementState()
        selection = FamilyActivitySelection()
    }

    // MARK: Private

    private func updateEnforcement(_ change: (inout EnforcementState) -> Void) {
        var state = SharedStore.loadEnforcement()
        change(&state)
        SharedStore.saveEnforcement(state)
        enforcement = state
        ShieldController.sync()
    }

    private func startMonitoring() {
        guard isScreenTimeAuthorized else { return }
        do {
            try ScreenTimeService.startDailyMonitoring()
        } catch {
            lastError = "Couldn't schedule daily blocking: \(error.localizedDescription)"
        }
    }
}
