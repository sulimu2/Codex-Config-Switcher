// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CodexConfigSwitcher",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "CodexConfigSwitcherCore",
            targets: ["CodexConfigSwitcherCore"]
        ),
        .executable(
            name: "CodexConfigSwitcher",
            targets: ["CodexConfigSwitcher"]
        ),
    ],
    targets: [
        .target(
            name: "CodexConfigSwitcherCore"
        ),
        .executableTarget(
            name: "CodexConfigSwitcher",
            dependencies: ["CodexConfigSwitcherCore"]
        ),
        .testTarget(
            name: "CodexConfigSwitcherCoreTests",
            dependencies: ["CodexConfigSwitcherCore"]
        ),
    ]
)
