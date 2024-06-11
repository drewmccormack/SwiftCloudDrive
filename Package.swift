// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftCloudDrive",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v15),
        .visionOS(.v1),
        .macCatalyst(.v15),
        .tvOS(.v15),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "SwiftCloudDrive",
            targets: ["SwiftCloudDrive"]),
    ],
    targets: [
        .target(
            name: "SwiftCloudDrive",
            dependencies: [],
            resources: [
                .copy("PrivacyInfo.xcprivacy")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]),
        .testTarget(
            name: "SwiftCloudDriveTests",
            dependencies: ["SwiftCloudDrive"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]),
    ],
    swiftLanguageVersions: [.v5, .v6]
)
