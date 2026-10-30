import FamilyControls
import GPSGymCore
import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var app

    enum Step: Int, CaseIterable {
        case welcome, goal, experience, schedule, setting, gym, apps, plan
    }

    @State private var step: Step = .welcome
    @State private var goal: FitnessGoal = .buildMuscle
    @State private var experience: Experience = .beginner
    @State private var days: Set<Weekday> = [.monday, .wednesday, .friday]
    @State private var minutes = 60
    @State private var mode: WorkoutMode = .gym
    @State private var equipment: Equipment = .fullGym
    @State private var gym: GymLocation?
    @State private var selection = FamilyActivitySelection()
    @State private var enforceToday = false

    private var profile: TrainingProfile {
        TrainingProfile(goal: goal, experience: experience, equipment: equipment, mode: mode, trainingDays: days, sessionMinutes: minutes)
    }

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome {
                header
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            footer
        }
        .background(Theme.background.ignoresSafeArea())
        .animation(.snappy, value: step)
    }

    // MARK: Chrome

    private var header: some View {
        HStack {
            Button { go(-1) } label: {
                Image(systemName: "chevron.left").font(.headline).frame(width: 44, height: 44)
            }
            ProgressView(value: Double(step.rawValue), total: Double(Step.allCases.count - 1))
                .tint(Theme.accent)
            Spacer().frame(width: 44)
        }
        .padding(.horizontal, 8)
    }

    private var footer: some View {
        Button(footerTitle) {
            if step == .plan {
                app.completeOnboarding(profile: profile, gym: mode == .gym ? gym : nil, selection: selection, enforceToday: enforceToday)
            } else {
                go(1)
            }
        }
        .buttonStyle(PrimaryButtonStyle(isEnabled: canContinue))
        .disabled(!canContinue)
        .padding(20)
    }

    private var hasPickedApps: Bool {
        app.isScreenTimeAuthorized && (!selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty)
    }

    private var footerTitle: String {
        switch step {
        case .plan: return "Start training"
        // Screen Time can't be authorized in the Simulator, and some users want to try the plan first.
        case .apps where !hasPickedApps: return "Set up blocking later"
        default: return "Continue"
        }
    }

    private var canContinue: Bool {
        switch step {
        case .schedule: return !days.isEmpty
        case .gym: return gym != nil
        default: return true
        }
    }

    private func go(_ delta: Int) {
        var next = step.rawValue + delta
        // Home workouts skip the gym location step.
        if Step(rawValue: next) == .gym, mode == .home { next += delta }
        if let target = Step(rawValue: next) { step = target }
    }

    // MARK: Steps

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome: welcome
        case .goal: goalStep
        case .experience: experienceStep
        case .schedule: scheduleStep
        case .setting: settingStep
        case .gym: gymStep
        case .apps: AppSelectionStep(selection: $selection)
        case .plan: planStep
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 60)
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 56))
                .foregroundStyle(Theme.accent)
            Text("Want to scroll?\nEarn it.")
                .font(.system(size: 40, weight: .heavy))
            Text("GPS-GYM builds your training plan, locks your most distracting apps on training days, and unlocks them when you finish your workout.")
                .font(.title3)
                .foregroundStyle(Theme.secondaryText)
            VStack(alignment: .leading, spacing: 10) {
                Label("A plan built for your goal", systemImage: "list.bullet.clipboard")
                Label("Apps locked until you train", systemImage: "lock.fill")
                Label("Verified at your gym, privately", systemImage: "location.fill")
            }
            .font(.headline)
            .padding(.top, 8)
        }
    }

    private func title(_ text: String, _ subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text).font(.largeTitle.weight(.bold))
            if let subtitle { Text(subtitle).foregroundStyle(Theme.secondaryText) }
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            title("What's your main goal?")
            ForEach(FitnessGoal.allCases) { option in
                OptionRow(title: option.title, systemImage: icon(for: option), isSelected: goal == option) { goal = option }
            }
        }
    }

    private func icon(for goal: FitnessGoal) -> String {
        switch goal {
        case .buildMuscle: return "figure.strengthtraining.traditional"
        case .getStronger: return "scalemass.fill"
        case .generalFitness: return "heart.fill"
        case .loseFat: return "flame.fill"
        }
    }

    private var experienceStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            title("How experienced are you?")
            ForEach(Experience.allCases) { option in
                OptionRow(title: option.title, subtitle: option.subtitle, isSelected: experience == option) { experience = option }
            }
        }
    }

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            title("When will you train?", "Apps lock on these days only. Keep at least one rest day.")
            WeekdayPicker(selection: $days)
            if days.count > 4, experience == .beginner {
                Text("Heads up: 3–4 days is plenty when you're starting out — and easier to stick with.")
                    .font(.footnote).foregroundStyle(Theme.locked)
            }
            Text("Session length").font(.headline)
            Picker("Session length", selection: $minutes) {
                ForEach(TrainingProfile.sessionLengthOptions, id: \.self) { Text("\($0) min").tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var settingStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            title("Where do you train?")
            ForEach(WorkoutMode.allCases) { option in
                OptionRow(
                    title: option.title,
                    subtitle: option == .gym ? "Location-verified check-in" : "Verified by time and logged sets",
                    systemImage: option == .gym ? "building.2.fill" : "house.fill",
                    isSelected: mode == option
                ) {
                    mode = option
                    if option == .home, equipment == .fullGym { equipment = .dumbbells }
                    if option == .gym { equipment = .fullGym }
                }
            }
            Text("Equipment").font(.headline).padding(.top, 8)
            ForEach(Equipment.allCases) { option in
                OptionRow(title: option.title, isSelected: equipment == option) { equipment = option }
            }
        }
    }

    private var gymStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("Set your gym", "We only check your location during workouts, and only store your distance from this spot.")
            GymLocationPicker(gym: $gym)
        }
    }

    private var planStep: some View {
        let plan = WorkoutGenerator.generate(for: profile)
        return VStack(alignment: .leading, spacing: 16) {
            title("Your plan is ready", plan.name)
            ForEach(plan.schedule, id: \.self) { scheduled in
                if let day = plan.days.first(where: { $0.id == scheduled.workoutDayID }) {
                    Card {
                        HStack {
                            Text(scheduled.weekday.shortName.uppercased())
                                .font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                                .frame(width: 40, alignment: .leading)
                            VStack(alignment: .leading) {
                                Text(day.name).font(.headline)
                                Text("\(day.exercises.count) exercises · ~\(day.estimatedMinutes) min")
                                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
                            }
                        }
                    }
                }
            }
            Toggle(isOn: $enforceToday) {
                VStack(alignment: .leading) {
                    Text("Start locking today").font(.headline)
                    Text("Off = blocking starts tomorrow").font(.caption).foregroundStyle(Theme.secondaryText)
                }
            }
            .tint(Theme.accent)
            Text("You stay in control: rest-day swaps and an emergency unlock are always available, and you can turn off GPS-GYM's access in iOS Settings at any time.")
                .font(.footnote).foregroundStyle(Theme.secondaryText)
        }
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.mondayFirst) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn {
                        selection.remove(day)
                    } else if selection.count < TrainingProfile.maxTrainingDays {
                        selection.insert(day)
                    }
                } label: {
                    Text(day.initial)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(isOn ? .black : .white)
                        .background(isOn ? Theme.accent : Theme.card, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.shortName)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

/// Screen Time permission + app selection. Shared by onboarding and Settings.
struct AppSelectionStep: View {
    @Environment(AppModel.self) private var app
    @Binding var selection: FamilyActivitySelection
    @State private var isPickerPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pick your distractions").font(.largeTitle.weight(.bold))
            Text("These lock on training days until your workout is verified. Apple keeps your choices private — GPS-GYM can't even see which apps you picked.")
                .foregroundStyle(Theme.secondaryText)

            if !app.isScreenTimeAuthorized {
                Card {
                    Label("Allow Screen Time access", systemImage: "hourglass").font(.headline)
                    Text("iOS will ask you to confirm with Face ID or your passcode.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                    Button("Allow access") { Task { await app.requestScreenTimeAuthorization() } }
                        .buttonStyle(SecondaryButtonStyle())
                }
                if let error = app.lastError {
                    Text(error).font(.footnote).foregroundStyle(Theme.danger)
                }
            } else {
                Card {
                    SelectionSummary(selection: selection)
                    Button(selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty ? "Choose apps" : "Edit apps") {
                        isPickerPresented = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
    }
}

struct SelectionSummary: View {
    let selection: FamilyActivitySelection

    var body: some View {
        if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty {
            Text("No apps selected yet").foregroundStyle(Theme.secondaryText)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(selection.applicationTokens.prefix(6)), id: \.self) { token in
                    Label(token).font(.subheadline)
                }
                let extraApps = selection.applicationTokens.count - 6
                if extraApps > 0 { Text("+\(extraApps) more apps").font(.caption).foregroundStyle(Theme.secondaryText) }
                if !selection.categoryTokens.isEmpty {
                    Text("\(selection.categoryTokens.count) categories").font(.caption).foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }
}
