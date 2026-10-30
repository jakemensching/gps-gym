import GPSGymCore
import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(AppModel.self) private var app
    @State private var shortfall: VerificationResult?
    @State private var confirmDiscard = false
    @State private var isFinishing = false

    var body: some View {
        if let draft = app.activeWorkout {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        statusHeader(draft)
                        ForEach(Array(draft.exercises.enumerated()), id: \.element.id) { index, log in
                            ExerciseCard(
                                log: log,
                                suggestion: Progression.suggest(for: log.planned, history: app.history(for: log.planned.exercise.id)),
                                onChange: { entry in update(exercise: index, entry: entry) }
                            )
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 100)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Theme.background.ignoresSafeArea())
                .safeAreaInset(edge: .bottom) { bottomBar(draft) }
                .navigationTitle(draft.day.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { confirmDiscard = true } label: { Image(systemName: "xmark") }
                    }
                }
                .task(id: draft.id) { await sampleLocationPeriodically() }
                .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                    Button("Discard workout", role: .destructive) { app.discardWorkout() }
                } message: {
                    Text("Nothing will be saved and your apps stay locked.")
                }
                .alert("Not quite yet", isPresented: Binding(get: { shortfall != nil }, set: { if !$0 { shortfall = nil } })) {
                    Button("Keep training", role: .cancel) {}
                    Button("Save without unlocking") { app.finishWorkout() }
                } message: {
                    Text((shortfall?.unmetReasons ?? []).joined(separator: "\n"))
                }
            }
        }
    }

    // MARK: Header

    private func statusHeader(_ draft: ActiveWorkoutDraft) -> some View {
        Card {
            HStack(alignment: .firstTextBaseline) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(formatDuration(context.date.timeIntervalSince(draft.startedAt)))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                Spacer()
                locationPill(draft)
            }
            ProgressView(value: Double(draft.completedSets), total: Double(max(1, draft.plannedSets)))
                .tint(Theme.accent)
            let policy = draft.policy
            let neededSets = Int((Double(draft.plannedSets) * policy.minimumSetCompletion).rounded(.up))
            Text("\(draft.completedSets)/\(draft.plannedSets) sets · unlock needs \(policy.minimumMinutes)+ min and \(neededSets)+ sets")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
            if let restEnds = draft.restEndsAt, restEnds > Date() {
                restBanner(until: restEnds)
            }
        }
    }

    @ViewBuilder private func locationPill(_ draft: ActiveWorkoutDraft) -> some View {
        if draft.mode == .home {
            StatusPill(text: "Home workout", color: Theme.secondaryText, systemImage: "house.fill")
        } else if !app.location.isAuthorized {
            Button { app.location.requestPermission() } label: {
                StatusPill(text: "Enable location", color: Theme.locked, systemImage: "location.slash")
            }
        } else if draft.locationSamples.isEmpty {
            StatusPill(text: "Checking…", color: Theme.secondaryText, systemImage: "location")
        } else {
            let status = Verifier.locationStatus(draft.locationSamples, mode: draft.mode, policy: draft.policy)
            StatusPill(
                text: status.label,
                color: status == .atGym ? Theme.accent : Theme.locked,
                systemImage: status == .atGym ? "checkmark.seal.fill" : "location.fill"
            )
        }
    }

    private func restBanner(until end: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = end.timeIntervalSince(context.date)
            HStack {
                Image(systemName: "timer")
                Text(remaining > 0 ? "Rest \(formatDuration(remaining))" : "Rest done — next set")
                    .monospacedDigit()
                Spacer()
                Button("Skip") { updateDraft { $0.restEndsAt = nil } }
                    .font(.caption.weight(.semibold))
            }
            .font(.subheadline.weight(.semibold))
            .padding(10)
            .background(Theme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(Theme.accent)
        }
    }

    private func bottomBar(_ draft: ActiveWorkoutDraft) -> some View {
        Button(isFinishing ? "Verifying…" : "Finish workout") {
            Task { await finish() }
        }
        .buttonStyle(PrimaryButtonStyle(isEnabled: !isFinishing))
        .disabled(isFinishing)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: Actions

    private func update(exercise index: Int, entry: SetEntry) {
        updateDraft { draft in
            guard let setIndex = draft.exercises[index].sets.firstIndex(where: { $0.id == entry.id }) else { return }
            let wasDone = draft.exercises[index].sets[setIndex].isDone
            draft.exercises[index].sets[setIndex] = entry
            if entry.isDone && !wasDone {
                draft.restEndsAt = Date().addingTimeInterval(TimeInterval(draft.exercises[index].planned.restSeconds))
            }
        }
    }

    private func updateDraft(_ change: (inout ActiveWorkoutDraft) -> Void) {
        guard var draft = app.activeWorkout else { return }
        change(&draft)
        app.activeWorkout = draft
    }

    private func sampleLocationPeriodically() async {
        while !Task.isCancelled {
            await app.recordLocationSample()
            try? await Task.sleep(for: .seconds(300))
        }
    }

    private func finish() async {
        isFinishing = true
        defer { isFinishing = false }
        await app.recordLocationSample()
        guard let result = app.previewVerification() else { return }
        if result.isVerified {
            app.finishWorkout()
        } else {
            shortfall = result
        }
    }
}

struct ExerciseCard: View {
    let log: ExerciseLog
    let suggestion: ProgressionSuggestion
    let onChange: (SetEntry) -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(log.planned.exercise.name).font(.headline)
                Text("\(log.planned.prescription) · rest \(log.planned.restSeconds / 60):\(String(format: "%02d", log.planned.restSeconds % 60))")
                    .font(.caption).foregroundStyle(Theme.secondaryText)
                Text(suggestion.message).font(.caption).foregroundStyle(Theme.accent)
            }
            HStack {
                Text("SET").frame(width: 32, alignment: .leading)
                if !log.planned.exercise.isBodyweight { Text("LB").frame(maxWidth: .infinity) }
                Text("REPS").frame(maxWidth: .infinity)
                Spacer().frame(width: 44)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.secondaryText)
            ForEach(Array(log.sets.enumerated()), id: \.element.id) { index, entry in
                SetRow(number: index + 1, entry: entry, isBodyweight: log.planned.exercise.isBodyweight, onChange: onChange)
            }
        }
    }
}

struct SetRow: View {
    let number: Int
    let entry: SetEntry
    let isBodyweight: Bool
    let onChange: (SetEntry) -> Void

    @State private var weightText: String
    @State private var repsText: String

    init(number: Int, entry: SetEntry, isBodyweight: Bool, onChange: @escaping (SetEntry) -> Void) {
        self.number = number
        self.entry = entry
        self.isBodyweight = isBodyweight
        self.onChange = onChange
        _weightText = State(initialValue: entry.weight.map(Progression.format) ?? "")
        _repsText = State(initialValue: String(entry.reps))
    }

    var body: some View {
        HStack {
            Text("\(number)").font(.headline).frame(width: 32, alignment: .leading)
            if !isBodyweight {
                field("lb", text: $weightText, keyboard: .decimalPad)
            }
            field("reps", text: $repsText, keyboard: .numberPad)
            Button {
                onChange(edited(isDone: !entry.isDone))
            } label: {
                Image(systemName: entry.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(entry.isDone ? Theme.accent : Theme.secondaryText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(entry.isDone ? "Mark set \(number) not done" : "Complete set \(number)")
        }
        .opacity(entry.isDone ? 0.75 : 1)
        .onChange(of: weightText) { onChange(edited(isDone: entry.isDone)) }
        .onChange(of: repsText) { onChange(edited(isDone: entry.isDone)) }
    }

    private func edited(isDone: Bool) -> SetEntry {
        var copy = entry
        copy.weight = Double(weightText.replacingOccurrences(of: ",", with: "."))
        copy.reps = Int(repsText) ?? 0
        copy.isDone = isDone
        return copy
    }

    private func field(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(.headline.monospacedDigit())
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct WorkoutResultView: View {
    let finished: FinishedWorkout
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: finished.result.isVerified ? "lock.open.fill" : "checkmark.circle")
                .font(.system(size: 56))
                .foregroundStyle(Theme.accent)
                .padding(.top, 32)
            Text(title).font(.title.weight(.bold)).multilineTextAlignment(.center)
            HStack(spacing: 12) {
                StatTile(value: "\(finished.record.durationMinutes)", label: "Minutes")
                StatTile(value: "\(finished.record.completedSets)", label: "Sets")
                StatTile(value: finished.record.totalVolume > 0 ? "\(Int(finished.record.totalVolume))" : "—", label: "Volume (lb)")
            }
            StatusPill(text: finished.result.location.label, color: Theme.secondaryText, systemImage: "location.fill")
            Spacer()
            Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
        .background(Theme.background.ignoresSafeArea())
    }

    private var title: String {
        if finished.unlockedApps { return "Unlocked. You earned it. 🔓" }
        if finished.result.isVerified { return "Workout verified 💪" }
        return "Workout saved"
    }
}
