import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings
import GPSGymCore

// Compiled into the app AND the Screen Time extensions. Keep it tiny:
// DeviceActivity extensions run under a strict memory limit (~6 MB).

enum AppGroup {
    /// Must match the App Group in project.yml and on the Apple Developer portal.
    static let identifier = "group.com.jakemensching.gpsgym"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

extension ManagedSettingsStore.Name {
    static let gpsGym = Self("gpsgym")
}

extension DeviceActivityName {
    /// Repeating 00:00–23:59 window; re-evaluates blocking at the start of each day.
    static let daily = Self("gpsgym.daily")
    /// One-off window used by the Blocking Lab to prove the extension fires with the app closed.
    static let labTest = Self("gpsgym.labTest")
}

enum SharedStore {
    private enum Key {
        static let enforcement = "enforcementState.v1"
        static let selection = "activitySelection.v1"
    }

    static func loadEnforcement() -> EnforcementState {
        guard let data = AppGroup.defaults.data(forKey: Key.enforcement),
              let state = try? JSONDecoder().decode(EnforcementState.self, from: data)
        else { return EnforcementState() }
        return state
    }

    static func saveEnforcement(_ state: EnforcementState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        AppGroup.defaults.set(data, forKey: Key.enforcement)
    }

    static func loadSelection() -> FamilyActivitySelection {
        guard let data = AppGroup.defaults.data(forKey: Key.selection),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return selection
    }

    static func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        AppGroup.defaults.set(data, forKey: Key.selection)
    }

    static func clearAll() {
        AppGroup.defaults.removeObject(forKey: Key.enforcement)
        AppGroup.defaults.removeObject(forKey: Key.selection)
    }
}

/// Applies or removes shields. Shields persist (even across reboots) until cleared.
enum ShieldController {
    private static let store = ManagedSettingsStore(named: .gpsGym)

    static func apply(_ selection: FamilyActivitySelection) {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    }

    static func clear() {
        store.clearAllSettings()
    }

    /// Make the shield match what `EnforcementState` says right now.
    @discardableResult
    static func sync(now: Date = Date()) -> Bool {
        let shouldShield = SharedStore.loadEnforcement().shouldShield(on: now)
        if shouldShield {
            apply(SharedStore.loadSelection())
        } else {
            clear()
        }
        return shouldShield
    }
}
