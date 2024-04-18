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
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SwiftCloudDrive",
            targets: ["SwiftCloudDrive"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SwiftCloudDrive",
            dependencies: [],
            resources: [
                .copy("PrivacyInfo.xcprivacy")
            ]),
        .testTarget(
            name: "SwiftCloudDriveTests",
            dependencies: ["SwiftCloudDrive"]),
    ]
)
