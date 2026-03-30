// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LightSwitcher",
    platforms: [
        .macOS(.v13),
    ],
    swiftLanguageVersions: [
        .v5,
    ],
    products: [
        .library(
            name: "SwitchCore",
            targets: ["SwitchCore"]
        ),
        .executable(
            name: "LightSwitcher",
            targets: ["LightSwitcher"]
        ),
    ],
    targets: [
        .target(
            name: "SwitchCore"
        ),
        .executableTarget(
            name: "LightSwitcher",
            dependencies: ["SwitchCore"]
        ),
        .testTarget(
            name: "SwitchCoreTests",
            dependencies: ["SwitchCore"]
        ),
    ]
)
