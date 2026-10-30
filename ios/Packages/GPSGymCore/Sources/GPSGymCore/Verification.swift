import Foundation

/// A single location check during a workout. We deliberately store only the
/// distance to the saved gym and the fix accuracy — never raw coordinates.
public struct LocationSample: Codable, Hashable, Sendable {
    public var date: Date
    public var distanceMeters: Double
    public var accuracyMeters: Double

    public init(date: Date, distanceMeters: Double, accuracyMeters: Double) {
        self.date = date
        self.distanceMeters = distanceMeters
        self.accuracyMeters = accuracyMeters
    }
}

public struct VerificationPolicy: Codable, Equatable, Sendable {
    public var minimumMinutes: Int
    /// Fraction of planned sets that must be logged.
    public var minimumSetCompletion: Double
    public var gymRadiusMeters: Double
    /// Fixes worse than this are treated as "no signal", not as "away from gym".
    public var maxUsableAccuracyMeters: Double

    public init(minimumMinutes: Int, minimumSetCompletion: Double = 0.6, gymRadiusMeters: Double = 150, maxUsableAccuracyMeters: Double = 200) {
        self.minimumMinutes = minimumMinutes
        self.minimumSetCompletion = minimumSetCompletion
        self.gymRadiusMeters = gymRadiusMeters
        self.maxUsableAccuracyMeters = maxUsableAccuracyMeters
    }

    /// Minimum duration: 60% of the planned session, never below 20 minutes.
    public static func standard(plannedMinutes: Int) -> VerificationPolicy {
        VerificationPolicy(minimumMinutes: max(20, Int(Double(plannedMinutes) * 0.6)))
    }
}

public struct SessionEvidence: Sendable {
    public var startedAt: Date
    public var endedAt: Date
    public var plannedSets: Int
    public var completedSets: Int
    public var mode: WorkoutMode
    public var locationSamples: [LocationSample]

    public init(startedAt: Date, endedAt: Date, plannedSets: Int, completedSets: Int, mode: WorkoutMode, locationSamples: [LocationSample]) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedSets = plannedSets
        self.completedSets = completedSets
        self.mode = mode
        self.locationSamples = locationSamples
    }

    public var durationMinutes: Double { endedAt.timeIntervalSince(startedAt) / 60 }
}

public enum LocationStatus: String, Codable, Sendable {
    case atGym, awayFromGym, noSignal, notRequired

    public var label: String {
        switch self {
        case .atGym: return "At gym"
        case .awayFromGym: return "Not at gym"
        case .noSignal: return "No GPS signal"
        case .notRequired: return "Home workout"
        }
    }
}

/// How much we trust that a real workout happened. Only ever shown to the user
/// and used for analytics — never to shame or punish.
public enum TrustLevel: String, Codable, Sendable {
    case high, medium, low
}

public struct VerificationResult: Equatable, Sendable {
    public var isVerified: Bool
    public var durationMet: Bool
    public var setsMet: Bool
    public var location: LocationStatus
    public var trust: TrustLevel
    public var unmetReasons: [String]
}

/// GPS can't prove anyone exercised. Verification combines cheap, privacy-light
/// signals so that faking it takes more effort than just doing a short workout.
public enum Verifier {
    public static func locationStatus(_ samples: [LocationSample], mode: WorkoutMode, policy: VerificationPolicy) -> LocationStatus {
        guard mode == .gym else { return .notRequired }
        let usable = samples.filter { $0.accuracyMeters >= 0 && $0.accuracyMeters <= policy.maxUsableAccuracyMeters }
        guard !usable.isEmpty else { return .noSignal }
        // Give the benefit of the doubt for the fix's uncertainty (indoor GPS drifts).
        let inside = usable.filter { $0.distanceMeters - $0.accuracyMeters <= policy.gymRadiusMeters }
        return Double(inside.count) / Double(usable.count) >= 0.5 ? .atGym : .awayFromGym
    }

    public static func evaluate(_ evidence: SessionEvidence, policy: VerificationPolicy) -> VerificationResult {
        let durationMet = evidence.durationMinutes >= Double(policy.minimumMinutes)
        let required = Int((Double(evidence.plannedSets) * policy.minimumSetCompletion).rounded(.up))
        let setsMet = evidence.completedSets >= max(1, required)
        let location = locationStatus(evidence.locationSamples, mode: evidence.mode, policy: policy)

        var reasons: [String] = []
        if !durationMet {
            let remaining = Int((Double(policy.minimumMinutes) - evidence.durationMinutes).rounded(.up))
            reasons.append("Train at least \(policy.minimumMinutes) min (\(remaining) to go).")
        }
        if !setsMet {
            reasons.append("Log at least \(required) of \(evidence.plannedSets) sets (\(evidence.completedSets) so far).")
        }
        if location == .awayFromGym {
            reasons.append("You don't appear to be at your gym. Switch to a home workout or check your gym location in Settings.")
        }

        // No signal is NOT a failure: indoor GPS is unreliable and we'd rather
        // trust an honest user than lock them out. It lowers trust instead.
        let trust: TrustLevel
        switch location {
        case .atGym: trust = .high
        case .notRequired: trust = .medium
        case .noSignal, .awayFromGym: trust = .low
        }

        return VerificationResult(
            isVerified: reasons.isEmpty,
            durationMet: durationMet,
            setsMet: setsMet,
            location: location,
            trust: trust,
            unmetReasons: reasons
        )
    }
}
