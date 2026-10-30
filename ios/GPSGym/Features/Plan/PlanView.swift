import GPSGymCore
import SwiftUI

struct PlanView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            List {
                if let plan = app.plan {
                    Section("Weekly schedule") {
                        ForEach(Weekday.mondayFirst) { weekday in
                            HStack {
                                Text(weekday.shortName).frame(width: 44, alignment: .leading).foregroundStyle(Theme.secondaryText)
                                if let day = plan.workoutDay(for: weekday) {
                                    NavigationLink(day.name) { WorkoutDayDetail(day: day) }
                                } else {
                                    Text("Rest").foregroundStyle(Theme.secondaryText)
                                }
                            }
                        }
                    }
                    Section("Workouts") {
                        ForEach(plan.days) { day in
                            NavigationLink {
                                WorkoutDayDetail(day: day)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(day.name).font(.headline)
                                    Text("\(day.focus) · ~\(day.estimatedMinutes) min").font(.caption).foregroundStyle(Theme.secondaryText)
                                }
                            }
                        }
                    }
                    Section("How to progress") {
                        ForEach(plan.progressionNotes, id: \.self) { note in
                            Text(note).font(.subheadline)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(app.plan?.name ?? "Plan")
        }
    }
}

struct WorkoutDayDetail: View {
    let day: WorkoutDay

    var body: some View {
        List {
            Section {
                Label("~\(day.estimatedMinutes) min · \(day.totalSets) sets", systemImage: "clock")
                    .foregroundStyle(Theme.secondaryText)
            }
            ForEach(day.exercises) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.exercise.name).font(.headline)
                        Spacer()
                        Text(item.prescription).font(.headline.monospacedDigit()).foregroundStyle(Theme.accent)
                    }
                    Text("\(item.role.rawValue.capitalized) · rest \(item.restSeconds)s")
                        .font(.caption).foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(day.name)
    }
}
