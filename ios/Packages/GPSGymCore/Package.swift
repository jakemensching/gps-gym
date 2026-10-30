// swift-tools-version:5.9
import PackageDescription

// Pure, Foundation-only logic shared by the app and its Screen Time extensions.
// No UIKit/SwiftUI/Apple-only frameworks here, so `swift test` runs anywhere.
let package = Package(
    name: "GPSGymCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GPSGymCore", targets: ["GPSGymCore"]),
    ],
    targets: [
        .target(name: "GPSGymCore"),
        .testTarget(name: "GPSGymCoreTests", dependencies: ["GPSGymCore"]),
    ]
)
