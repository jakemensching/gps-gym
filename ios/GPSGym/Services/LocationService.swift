import CoreLocation
import Foundation
import GPSGymCore
import Observation

/// One-shot, When-In-Use location checks. No background tracking, no "Always"
/// permission, no stored coordinates — only distance-to-gym per sample.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var pending: [CheckedContinuation<CLLocation?, Never>] = []
    @ObservationIgnored private var requestID = 0

    override init() {
        super.init()
        authorization = manager.authorizationStatus
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Current fix, or nil after ~15s / on error / without permission.
    func currentLocation() async -> CLLocation? {
        guard isAuthorized else { return nil }
        return await withCheckedContinuation { continuation in
            pending.append(continuation)
            guard pending.count == 1 else { return } // a request is already in flight
            requestID += 1
            let id = requestID
            manager.requestLocation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                guard let self, self.requestID == id else { return }
                self.resolve(nil)
            }
        }
    }

    func sample(distanceTo gym: GymLocation) async -> LocationSample? {
        guard let location = await currentLocation() else { return nil }
        let gymLocation = CLLocation(latitude: gym.latitude, longitude: gym.longitude)
        return LocationSample(
            date: Date(),
            distanceMeters: location.distance(from: gymLocation),
            accuracyMeters: location.horizontalAccuracy
        )
    }

    private func resolve(_ location: CLLocation?) {
        let waiting = pending
        pending.removeAll()
        waiting.forEach { $0.resume(returning: location) }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        resolve(locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resolve(nil)
    }
}
