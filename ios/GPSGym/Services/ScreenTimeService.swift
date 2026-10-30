import DeviceActivity
import FamilyControls
import Foundation

/// Wraps FamilyControls authorization and DeviceActivity scheduling (app side only).
enum ScreenTimeService {
    static var isAuthorized: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    /// Shows Apple's system sheet; user confirms with Face ID / passcode.
    /// Fails in the Simulator — test on a real iPhone.
    static func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    /// Repeating daily window so the extension re-evaluates the lock every midnight,
    /// even if GPS-GYM is never opened.
    static func startDailyMonitoring() throws {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let center = DeviceActivityCenter()
        center.stopMonitoring([.daily])
        try center.startMonitoring(.daily, during: schedule)
    }

    static func stopAllMonitoring() {
        DeviceActivityCenter().stopMonitoring()
    }

    static var monitoredActivities: [DeviceActivityName] {
        DeviceActivityCenter().activities
    }

    /// Blocking Lab: shield starts in ~1 minute and lasts 15 (Apple's minimum interval).
    /// Close the app after scheduling — if the shield appears, the extension works.
    static func scheduleLabTest(now: Date = Date()) throws -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = now.addingTimeInterval(60)
        let end = start.addingTimeInterval(16 * 60)
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: start),
            intervalEnd: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: end),
            repeats: false
        )
        let center = DeviceActivityCenter()
        center.stopMonitoring([.labTest])
        try center.startMonitoring(.labTest, during: schedule)
        return (start, end)
    }
}
