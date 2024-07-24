// swift-tools-version: 5.10

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
//                .enableExperimentalFeature("StrictConcurrency")
            ]),
        .testTarget(
            name: "SwiftCloudDriveTests",
            dependencies: ["SwiftCloudDrive"],
            swiftSettings: [
//                .enableExperimentalFeature("StrictConcurrency")
            ]),
    ],
    swiftLanguageVersions: [.v5, .version("6")]
)
