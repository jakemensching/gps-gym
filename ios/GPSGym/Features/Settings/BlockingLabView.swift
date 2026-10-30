#if DEBUG
import DeviceActivity
import FamilyControls
import GPSGymCore
import SwiftUI

/// Proof-of-concept screen for the riskiest dependency: can we lock user-picked
/// apps and unlock them from code? Run every check on a physical iPhone.
/// See docs/POC-BLOCKING.md for the full test script.
struct BlockingLabView: View {
    @Environment(AppModel.self) private var app
    @State private var log: [String] = []

    var body: some View {
        List {
            Section("State") {
                row("Screen Time authorized", app.isScreenTimeAuthorized ? "yes" : "no")
                row("Apps / categories", "\(app.selection.applicationTokens.count) / \(app.selection.categoryTokens.count)")
                row("Today's status", "\(app.todayStatus)")
                row("Monitoring", ScreenTimeService.monitoredActivities.map(\.rawValue).joined(separator: ", "))
            }
            Section("1 · Shield from the app") {
                Button("Apply shield now") {
                    ShieldController.apply(app.selection)
                    note("Applied shield. Open a locked app — you should see the GPS-GYM shield.")
                }
                Button("Clear shield now") {
                    ShieldController.clear()
                    note("Cleared shield. Locked apps should open normally.")
                }
            }
            Section("2 · Shield from the extension (app closed)") {
                Button("Schedule 15-min lock starting in 1 min") {
                    do {
                        let window = try ScreenTimeService.scheduleLabTest()
                        note("Scheduled \(window.start.formatted(date: .omitted, time: .standard)) → \(window.end.formatted(date: .omitted, time: .standard)). Force-quit GPS-GYM now and wait.")
                    } catch {
                        note("Schedule failed: \(error)")
                    }
                }
            }
            Section("3 · Real loop") {
                Button("Re-sync with today's schedule") {
                    let shielded = ShieldController.sync()
                    note(shielded ? "Sync → shield ON (training day, not done)." : "Sync → shield OFF.")
                }
                Button("Simulate verified workout (unlock today)") {
                    app.startWorkout(app.todayWorkout ?? app.plan!.days[0])
                    // Back-date the start and mark every set done so verification passes.
                    if var draft = app.activeWorkout {
                        draft.startedAt = Date().addingTimeInterval(-90 * 60)
                        for i in draft.exercises.indices {
                            for j in draft.exercises[i].sets.indices { draft.exercises[i].sets[j].isDone = true }
                        }
                        draft.mode = .home
                        app.activeWorkout = draft
                    }
                    let result = app.finishWorkout()
                    note("Simulated workout verified=\(result?.isVerified ?? false). Status now \(app.todayStatus).")
                }
            }
            if !log.isEmpty {
                Section("Log") {
                    ForEach(log.reversed(), id: \.self) { Text($0).font(.caption.monospaced()) }
                }
            }
        }
        .navigationTitle("Blocking Lab")
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundStyle(.secondary) }
    }

    private func note(_ message: String) {
        log.append("\(Date().formatted(date: .omitted, time: .standard))  \(message)")
    }
}
#endif
