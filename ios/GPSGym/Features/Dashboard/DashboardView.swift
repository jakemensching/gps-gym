import GPSGymCore
import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var app
    @State private var confirmEmergency = false
    @State private var confirmRestSwap = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LockStatusCard(status: app.todayStatus, hasApps: app.hasSelectedApps, authorized: app.isScreenTimeAuthorized)
                    todayCard
                    HStack(spacing: 12) {
                        StatTile(value: "\(app.currentStreak)", label: "Day streak", systemImage: "flame.fill")
                        StatTile(value: "\(app.thisWeek.completed)/\(app.thisWeek.scheduled)", label: "This week", systemImage: "calendar")
                    }
                    WeekStrip(enforcement: app.enforcement)
                    if app.todayStatus == .locked { safetyValves }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(Date().formatted(.dateTime.weekday(.wide).month().day()))
            .confirmationDialog("Emergency unlock?", isPresented: $confirmEmergency, titleVisibility: .visible) {
                Button("Unlock for today", role: .destructive) { app.emergencyUnlockToday() }
            } message: {
                Text("Your apps unlock for the rest of today. This is logged and resets your streak.")
            }
            .confirmationDialog("Take a rest day?", isPresented: $confirmRestSwap, titleVisibility: .visible) {
                Button("Make today a rest day") { app.swapRestDayToday() }
            } message: {
                Text("Feeling sick, sore or traveling? One rest-day swap per week. Your streak stays intact.")
            }
        }
    }

    @ViewBuilder private var todayCard: some View {
        // An in-progress workout is always shown full-screen, so no "resume" state is needed here.
        if let day = app.todayWorkout {
            WorkoutSummaryCard(eyebrow: "TODAY", day: day, buttonTitle: app.todayStatus == .unlockedByWorkout ? "Train again" : "Start workout") {
                app.startWorkout(day)
            }
        } else if let next = app.nextWorkout {
            Card {
                Text("REST DAY").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                Text("Recover. Eat. Sleep.").font(.title2.weight(.bold))
                Text("Next up: \(next.day.name) on \(next.weekday.shortName)")
                    .foregroundStyle(Theme.secondaryText)
                Button("Train anyway") { app.startWorkout(next.day) }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var safetyValves: some View {
        VStack(spacing: 10) {
            if app.canSwapRestDayToday {
                Button("Need a rest day?") { confirmRestSwap = true }
                    .buttonStyle(SecondaryButtonStyle())
            }
            Button("Emergency unlock") { confirmEmergency = true }
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

struct LockStatusCard: View {
    let status: DayStatus
    let hasApps: Bool
    let authorized: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
            Spacer()
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(color.opacity(0.4)))
    }

    private var problem: String? {
        if !authorized { return "Screen Time access is off — blocking can't work. Fix it in Settings." }
        if !hasApps { return "No apps selected to lock. Pick some in Settings." }
        return nil
    }

    private var icon: String {
        if problem != nil { return "exclamationmark.triangle.fill" }
        switch status {
        case .locked: return "lock.fill"
        case .unlockedByWorkout: return "lock.open.fill"
        case .restDay, .unlockedByRestSwap: return "moon.zzz.fill"
        case .unlockedByEmergency: return "exclamationmark.lock.fill"
        case .notEnforced: return "pause.circle.fill"
        }
    }

    private var color: Color {
        if problem != nil { return Theme.danger }
        switch status {
        case .locked: return Theme.locked
        case .unlockedByWorkout: return Theme.accent
        default: return Theme.secondaryText
        }
    }

    private var title: String {
        if problem != nil { return "Blocking is off" }
        switch status {
        case .locked: return "Apps locked"
        case .unlockedByWorkout: return "Unlocked — you earned it"
        case .restDay: return "Rest day — apps open"
        case .unlockedByRestSwap: return "Rest day swap — apps open"
        case .unlockedByEmergency: return "Emergency unlock used"
        case .notEnforced: return "Blocking not active yet"
        }
    }

    private var subtitle: String {
        if let problem { return problem }
        switch status {
        case .locked: return "Finish today's workout to unlock."
        case .unlockedByWorkout: return "Workout verified. Enjoy your scroll."
        case .restDay, .unlockedByRestSwap: return "Recovery is part of the plan."
        case .unlockedByEmergency: return "Back at it next training day."
        case .notEnforced: return "Starts on your next training day, or it's paused in Settings."
        }
    }
}

struct WorkoutSummaryCard: View {
    let eyebrow: String
    let day: WorkoutDay
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        Card {
            Text(eyebrow).font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
            Text(day.name).font(.title2.weight(.bold))
            Text(day.focus).foregroundStyle(Theme.secondaryText)
            HStack(spacing: 16) {
                Label("~\(day.estimatedMinutes) min", systemImage: "clock")
                Label("\(day.exercises.count) exercises", systemImage: "dumbbell")
                Label("\(day.totalSets) sets", systemImage: "square.stack.3d.up")
            }
            .font(.caption)
            .foregroundStyle(Theme.secondaryText)
            Button(buttonTitle, action: action).buttonStyle(PrimaryButtonStyle())
        }
    }
}

struct WeekStrip: View {
    let enforcement: EnforcementState

    var body: some View {
        let week = WeekWindow(containing: Date())
        let todayKey = DayKey.make(Date())
        HStack(spacing: 6) {
            ForEach(week.days, id: \.self) { date in
                let key = DayKey.make(date)
                let isTraining = enforcement.trainingWeekdays.contains(Weekday(date: date))
                let isDone = enforcement.completedDays.contains(key)
                VStack(spacing: 6) {
                    Text(Weekday(date: date).initial)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(key == todayKey ? Theme.accent : Theme.secondaryText)
                    ZStack {
                        Circle()
                            .fill(isDone ? Theme.accent : Color.clear)
                            .overlay(Circle().stroke(isTraining ? Theme.accent : Theme.cardStroke, lineWidth: 2))
                        if isDone { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.black) }
                    }
                    .frame(width: 30, height: 30)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
