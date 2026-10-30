import SwiftUI

@main
struct GPSGymApp: App {
    @State private var app = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .active { app.refresh() }
                }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        if app.isOnboarded {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}

struct MainTabView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Today", systemImage: "flame.fill") }
            PlanView()
                .tabItem { Label("Plan", systemImage: "list.bullet.rectangle") }
            ProgressScreen()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        // The cover is driven purely by model state; the workout view finishes or discards itself.
        .fullScreenCover(isPresented: Binding(get: { app.activeWorkout != nil }, set: { _ in })) {
            ActiveWorkoutView()
                .environment(app)
        }
        .sheet(item: Binding(get: { app.lastFinished }, set: { _ in app.lastFinished = nil })) { finished in
            WorkoutResultView(finished: finished)
                .presentationDetents([.medium, .large])
        }
    }
}
