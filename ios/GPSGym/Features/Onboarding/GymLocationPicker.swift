import MapKit
import SwiftUI

/// Search for a gym or drop a pin at your current location.
struct GymLocationPicker: View {
    @Environment(AppModel.self) private var app
    @Binding var gym: GymLocation?

    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isLocating = false
    @State private var message: String?

    private let radius: CLLocationDistance = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let gym {
                let center = CLLocationCoordinate2D(latitude: gym.latitude, longitude: gym.longitude)
                Map(initialPosition: .region(MKCoordinateRegion(center: center, latitudinalMeters: 600, longitudinalMeters: 600))) {
                    Marker(gym.name, systemImage: "dumbbell.fill", coordinate: center).tint(Theme.accent)
                    MapCircle(center: center, radius: radius)
                        .foregroundStyle(Theme.accent.opacity(0.2))
                        .stroke(Theme.accent, lineWidth: 2)
                }
                .id("\(gym.latitude),\(gym.longitude)")
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                Label(gym.name, systemImage: "checkmark.circle.fill")
                    .font(.headline).foregroundStyle(Theme.accent)
            }

            Button {
                Task { await useCurrentLocation() }
            } label: {
                Label(isLocating ? "Locating…" : "I'm at my gym right now", systemImage: "location.fill")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isLocating)

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondaryText)
                TextField("Search gyms (e.g. ARC Champaign)", text: $query)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .onSubmit { Task { await search() } }
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))

            ForEach(results, id: \.self) { item in
                Button {
                    let coordinate = item.placemark.coordinate
                    gym = GymLocation(name: item.name ?? "My gym", latitude: coordinate.latitude, longitude: coordinate.longitude)
                    results = []
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name ?? "Unknown").font(.headline)
                        Text(item.placemark.title ?? "").font(.caption).foregroundStyle(Theme.secondaryText).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            if let message {
                Text(message).font(.footnote).foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func useCurrentLocation() async {
        if !app.location.isAuthorized {
            app.location.requestPermission()
            if app.location.isDenied {
                message = "Location is off for GPS-GYM. Enable it in Settings, or search for your gym instead."
                return
            }
            // Give the permission prompt a moment to resolve.
            try? await Task.sleep(for: .seconds(1))
        }
        isLocating = true
        defer { isLocating = false }
        guard let location = await app.location.currentLocation() else {
            message = "Couldn't get a GPS fix. Try searching for your gym instead."
            return
        }
        gym = GymLocation(name: "My gym", latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        message = nil
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = .pointOfInterest
        do {
            results = Array(try await MKLocalSearch(request: request).start().mapItems.prefix(6))
            message = results.isEmpty ? "No results. Try a different name." : nil
        } catch {
            message = "Search failed. Check your connection and try again."
        }
    }
}
