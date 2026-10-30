import Charts
import GPSGymCore
import SwiftUI

/// Named ProgressScreen to avoid clashing with SwiftUI.ProgressView.
struct ProgressScreen: View {
    @Environment(AppModel.self) private var app

    private var verified: [WorkoutRecord] { app.workouts.filter(\.isVerified) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        StatTile(value: "\(verified.count)", label: "Workouts", systemImage: "checkmark.seal.fill")
                        StatTile(value: "\(app.currentStreak)", label: "Streak", systemImage: "flame.fill")
                    }
                    weeklyChart
                    exerciseList
                    recentList
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Progress")
        }
    }

    private struct WeekPoint: Identifiable {
        let id: Int
        let label: String
        let completed: Int
        let scheduled: Int
    }

    private var weeks: [WeekPoint] {
        (0..<8).reversed().map { offset in
            let date = Calendar.current.date(byAdding: .weekOfYear, value: -offset, to: Date()) ?? Date()
            let adherence = app.enforcement.weeklyAdherence(containing: date)
            let monday = WeekWindow(containing: date).days.first ?? date
            return WeekPoint(id: offset, label: monday.formatted(.dateTime.month(.defaultDigits).day()), completed: adherence.completed, scheduled: adherence.scheduled)
        }
    }

    private var weeklyChart: some View {
        Card {
            Text("Weekly consistency").font(.headline)
            Chart(weeks) { week in
                BarMark(x: .value("Week", week.label), y: .value("Scheduled", week.scheduled))
                    .foregroundStyle(Color.white.opacity(0.12))
                BarMark(x: .value("Week", week.label), y: .value("Completed", week.completed))
                    .foregroundStyle(Theme.accent)
            }
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
            .frame(height: 160)
            Text("Completed vs scheduled sessions, last 8 weeks").font(.caption).foregroundStyle(Theme.secondaryText)
        }
    }

    private struct ExerciseSummary: Identifiable {
        let id: String
        let name: String
        let bestE1RM: Double
        let sessions: Int
    }

    private var exerciseSummaries: [ExerciseSummary] {
        var byID: [String: (name: String, best: Double, sessions: Int)] = [:]
        for record in app.workouts {
            for log in record.exercises where !log.completedSets.isEmpty {
                let best = log.completedSets.compactMap { Progression.estimatedOneRepMax(LoggedSet(weight: $0.weight, reps: $0.reps)) }.max() ?? 0
                let current = byID[log.planned.exercise.id]
                byID[log.planned.exercise.id] = (log.planned.exercise.name, max(best, current?.best ?? 0), (current?.sessions ?? 0) + 1)
            }
        }
        return byID.map { ExerciseSummary(id: $0.key, name: $0.value.name, bestE1RM: $0.value.best, sessions: $0.value.sessions) }
            .sorted { $0.sessions > $1.sessions }
    }

    @ViewBuilder private var exerciseList: some View {
        let summaries = exerciseSummaries
        if !summaries.isEmpty {
            Card {
                Text("Exercises").font(.headline)
                ForEach(summaries) { summary in
                    NavigationLink {
                        ExerciseProgressView(exerciseID: summary.id, name: summary.name)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(summary.name).font(.subheadline.weight(.semibold))
                                Text("\(summary.sessions) sessions").font(.caption).foregroundStyle(Theme.secondaryText)
                            }
                            Spacer()
                            if summary.bestE1RM > 0 {
                                Text("e1RM \(Int(summary.bestE1RM)) lb").font(.subheadline.monospacedDigit()).foregroundStyle(Theme.accent)
                            }
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder private var recentList: some View {
        if app.workouts.isEmpty {
            Card {
                Text("No workouts yet").font(.headline)
                Text("Finish your first session and your progress shows up here.").foregroundStyle(Theme.secondaryText)
            }
        } else {
            Card {
                Text("Recent sessions").font(.headline)
                ForEach(app.workouts.sorted { $0.startedAt > $1.startedAt }.prefix(10)) { record in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(record.workoutName).font(.subheadline.weight(.semibold))
                            Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(Theme.secondaryText)
                        }
                        Spacer()
                        Text("\(record.durationMinutes) min · \(record.completedSets) sets")
                            .font(.caption).foregroundStyle(Theme.secondaryText)
                        Image(systemName: record.isVerified ? "checkmark.seal.fill" : "seal")
                            .foregroundStyle(record.isVerified ? Theme.accent : Theme.secondaryText)
                    }
                }
            }
        }
    }
}

struct ExerciseProgressView: View {
    @Environment(AppModel.self) private var app
    let exerciseID: String
    let name: String

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let e1rm: Double
        let topSet: String
    }

    private var points: [Point] {
        app.workouts.sorted { $0.startedAt < $1.startedAt }.compactMap { record in
            guard let log = record.exercises.first(where: { $0.planned.exercise.id == exerciseID }),
                  let top = log.completedSets.max(by: {
                      (Progression.estimatedOneRepMax(LoggedSet(weight: $0.weight, reps: $0.reps)) ?? Double($0.reps))
                          < (Progression.estimatedOneRepMax(LoggedSet(weight: $1.weight, reps: $1.reps)) ?? Double($1.reps))
                  })
            else { return nil }
            let e1rm = Progression.estimatedOneRepMax(LoggedSet(weight: top.weight, reps: top.reps)) ?? Double(top.reps)
            let label = top.weight.map { "\(Progression.format($0)) lb × \(top.reps)" } ?? "\(top.reps) reps"
            return Point(date: record.startedAt, e1rm: e1rm, topSet: label)
        }
    }

    var body: some View {
        List {
            Section {
                Chart(points) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Estimated 1RM", point.e1rm))
                        .foregroundStyle(Theme.accent)
                    PointMark(x: .value("Date", point.date), y: .value("Estimated 1RM", point.e1rm))
                        .foregroundStyle(Theme.accent)
                }
                .frame(height: 200)
            } footer: {
                Text("Estimated 1-rep max from your best set each session (reps for bodyweight moves).")
            }
            Section("Top sets") {
                ForEach(points.reversed()) { point in
                    HStack {
                        Text(point.date.formatted(date: .abbreviated, time: .omitted))
                        Spacer()
                        Text(point.topSet).monospacedDigit()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(name)
    }
}
