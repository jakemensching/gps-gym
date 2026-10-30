import GPSGymCore
import SwiftUI

enum Theme {
    static let accent = Color(red: 0.80, green: 1.0, blue: 0.24)
    static let background = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let card = Color(white: 0.11)
    static let cardStroke = Color.white.opacity(0.08)
    static let secondaryText = Color.white.opacity(0.6)
    static let danger = Color(red: 1.0, green: 0.36, blue: 0.36)
    static let locked = Color(red: 1.0, green: 0.62, blue: 0.2)
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.cardStroke))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(isEnabled ? Theme.accent : Theme.accent.opacity(0.3), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.1), in: Capsule())
    }
}

/// Large tappable option used throughout onboarding.
struct OptionRow: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .frame(width: 28)
                        .foregroundStyle(isSelected ? Theme.accent : .white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.subheadline).foregroundStyle(Theme.secondaryText)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.secondaryText)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Theme.accent : Theme.cardStroke, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).foregroundStyle(Theme.accent) }
                Text(value).font(.title2.weight(.bold)).monospacedDigit()
            }
            Text(label).font(.caption).foregroundStyle(Theme.secondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(color)
        .background(color.opacity(0.15), in: Capsule())
    }
}

func formatDuration(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval))
    let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
    return hours > 0
        ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
        : String(format: "%d:%02d", minutes, seconds)
}

/// Shows the recommended session length; "Don't like it?" reveals a custom entry.
struct SessionLengthPicker: View {
    let recommended: Int
    @Binding var custom: Int?
    @State private var text = ""

    var body: some View {
        Card {
            if custom == nil {
                Text("Session length").font(.caption).foregroundStyle(Theme.secondaryText)
                HStack {
                    Label("\(recommended) min", systemImage: "timer").font(.title2.weight(.bold))
                    StatusPill(text: "Recommended", color: Theme.accent)
                }
                Text("Based on your goals and experience.").font(.caption).foregroundStyle(Theme.secondaryText)
                Button("Don't like the length? Enter your own") {
                    text = String(recommended)
                    custom = recommended
                }
                .font(.subheadline.weight(.semibold))
            } else {
                Text("Your session length (minutes)").font(.caption).foregroundStyle(Theme.secondaryText)
                TextField("Minutes", text: $text)
                    .keyboardType(.numberPad)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .onChange(of: text) {
                        if let n = Int(text), (TrainingProfile.minSessionMinutes...TrainingProfile.maxSessionMinutes).contains(n) {
                            custom = n
                        }
                    }
                if let n = Int(text), !(TrainingProfile.minSessionMinutes...TrainingProfile.maxSessionMinutes).contains(n) {
                    Text("Pick \(TrainingProfile.minSessionMinutes)–\(TrainingProfile.maxSessionMinutes) minutes.")
                        .font(.caption).foregroundStyle(Theme.locked)
                }
                Button("Use recommended (\(recommended) min)") { custom = nil }
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .onAppear { text = String(custom ?? recommended) }
    }
}
