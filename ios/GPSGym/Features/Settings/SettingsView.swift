import FamilyControls
import GPSGymCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @State private var editingApps = false
    @State private var editingTraining = false
    @State private var editingGym = false
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                blockingSection
                trainingSection
                permissionsSection
                Section {
                    Button("Reset all data", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Your plan, workouts and gym location are stored only on this iPhone.")
                }
                #if DEBUG
                Section("Developer") {
                    NavigationLink("Blocking Lab (proof of concept)") { BlockingLabView() }
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .sheet(isPresented: $editingApps) { AppSelectionSheet() }
            .sheet(isPresented: $editingTraining) { EditTrainingView() }
            .sheet(isPresented: $editingGym) { EditGymView() }
            .confirmationDialog("Reset everything?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Erase all data", role: .destructive) { app.resetEverything() }
            } message: {
                Text("Removes your plan, workout history and blocking schedule, and unlocks all apps.")
            }
        }
    }

    private var blockingSection: some View {
        Section {
            HStack {
                Text("Screen Time access")
                Spacer()
                StatusPill(
                    text: app.isScreenTimeAuthorized ? "On" : "Off",
                    color: app.isScreenTimeAuthorized ? Theme.accent : Theme.danger
                )
            }
            if !app.isScreenTimeAuthorized {
                Button("Turn on Screen Time access") { Task { await app.requestScreenTimeAuthorization() } }
            }
            Button {
                editingApps = true
            } label: {
                HStack {
                    Text("Locked apps")
                    Spacer()
                    Text("\(app.selection.applicationTokens.count) apps, \(app.selection.categoryTokens.count) categories")
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .disabled(!app.isScreenTimeAuthorized)
            Toggle("Pause blocking", isOn: Binding(get: { app.enforcement.isPaused }, set: { app.setPaused($0) }))
                .tint(Theme.accent)
        } header: {
            Text("Blocking")
        } footer: {
            Text("You're always in control: you can also revoke GPS-GYM's access in iOS Settings → Screen Time at any time.")
        }
    }

    private var trainingSection: some View {
        Section("Training") {
            if let setup = app.setup {
                Button { editingTraining = true } label: {
                    HStack {
                        Text("Training preferences")
                        Spacer()
                        Text("\(FitnessGoal.priority.filter(setup.profile.goals.contains).map(\.title).joined(separator: ", ")) · \(setup.profile.trainingDays.count)×/wk")
                            .lineLimit(1)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                Button { editingGym = true } label: {
                    HStack {
                        Text("Gym location")
                        Spacer()
                        Text(setup.gym?.name ?? "Not set").foregroundStyle(Theme.secondaryText)
                    }
                }
            }
        }
    }

    private var permissionsSection: some View {
        Section("Permissions") {
            HStack {
                Text("Location (during workouts)")
                Spacer()
                Text(app.location.isAuthorized ? "Allowed" : (app.location.isDenied ? "Denied" : "Not asked"))
                    .foregroundStyle(Theme.secondaryText)
            }
            if app.location.isDenied {
                Button("Open iOS Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            } else if !app.location.isAuthorized {
                Button("Allow location") { app.location.requestPermission() }
            }
        }
    }
}

private struct AppSelectionSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        NavigationStack {
            ScrollView { AppSelectionStep(selection: $selection).padding(20) }
                .background(Theme.background.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            app.updateSelection(selection)
                            dismiss()
                        }
                    }
                }
        }
        .onAppear { selection = app.selection }
    }
}

private struct EditGymView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var gym: GymLocation?

    var body: some View {
        NavigationStack {
            ScrollView { GymLocationPicker(gym: $gym).padding(20) }
                .background(Theme.background.ignoresSafeArea())
                .navigationTitle("Gym location")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            app.updateGym(gym)
                            dismiss()
                        }
                        .disabled(gym == nil)
                    }
                }
        }
        .onAppear { gym = app.setup?.gym }
    }
}

private struct EditTrainingView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var profile: TrainingProfile?

    var body: some View {
        NavigationStack {
            Form {
                if let binding = Binding($profile) {
                    Section("Goals (select all that apply)") {
                        ForEach(FitnessGoal.allCases) { goal in
                            Toggle(goal.title, isOn: Binding(
                                get: { binding.wrappedValue.goals.contains(goal) },
                                set: { isOn in
                                    if isOn { binding.wrappedValue.goals.insert(goal) } else { binding.wrappedValue.goals.remove(goal) }
                                }
                            ))
                            .tint(Theme.accent)
                        }
                    }
                    Picker("Experience", selection: binding.experience) {
                        ForEach(Experience.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Where", selection: binding.mode) {
                        ForEach(WorkoutMode.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Equipment", selection: binding.equipment) {
                        ForEach(Equipment.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper(
                        "Session length: \(binding.wrappedValue.sessionMinutes) min",
                        value: binding.sessionMinutes,
                        in: TrainingProfile.minSessionMinutes...TrainingProfile.maxSessionMinutes,
                        step: 5
                    )
                    Button("Use recommended (\(TrainingProfile.recommendedSessionMinutes(goals: binding.wrappedValue.goals, experience: binding.wrappedValue.experience)) min)") {
                        binding.wrappedValue.sessionMinutes = TrainingProfile.recommendedSessionMinutes(
                            goals: binding.wrappedValue.goals, experience: binding.wrappedValue.experience
                        )
                    }
                    Section("Training days") {
                        WeekdayPicker(selection: binding.trainingDays)
                    }
                    Section {
                        Text("Saving regenerates your plan. Your workout history is kept.")
                            .font(.footnote).foregroundStyle(Theme.secondaryText)
                    }
                }
            }
            .navigationTitle("Training")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let profile { app.updateProfile(profile) }
                        dismiss()
                    }
                    .disabled(profile?.trainingDays.isEmpty ?? true || profile?.goals.isEmpty ?? true)
                }
            }
        }
        .onAppear { profile = app.setup?.profile }
    }
}
