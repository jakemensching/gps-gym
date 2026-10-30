import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Custom copy on the screen users see when they open a blocked app.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        let lime = UIColor(red: 0.80, green: 1.0, blue: 0.24, alpha: 1)
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(white: 0.05, alpha: 0.9),
            icon: UIImage(systemName: "figure.strengthtraining.traditional"),
            title: .init(text: "Earn your scroll", color: .white),
            subtitle: .init(text: "Today is a training day. Finish your workout in GPS-GYM to unlock.", color: .lightGray),
            primaryButtonLabel: .init(text: "Got it", color: .black),
            primaryButtonBackgroundColor: lime
        )
    }
}
