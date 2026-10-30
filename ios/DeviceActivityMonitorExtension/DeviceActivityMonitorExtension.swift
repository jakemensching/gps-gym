import DeviceActivity
import Foundation

/// Runs in a separate process, even when GPS-GYM is closed. This is what
/// re-locks apps at the start of each training day.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        switch activity {
        case .labTest:
            ShieldController.apply(SharedStore.loadSelection())
        default:
            ShieldController.sync()
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        switch activity {
        case .labTest:
            // Restore whatever the real schedule says.
            ShieldController.sync()
        default:
            // End of day: never carry a lock into tomorrow. The next interval re-evaluates.
            ShieldController.clear()
        }
    }
}
