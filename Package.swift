// swift-tools-version: 6.2

import PackageDescription

var products: [Product] = [
    .library(
        name: "CodexConfigSwitcherCore",
        targets: ["CodexConfigSwitcherCore"]
    ),
    .executable(
        name: "CodexConfigSwitcherCLI",
        targets: ["CodexConfigSwitcherCLI"]
    ),
]

var targets: [Target] = [
    .target(
        name: "CodexConfigSwitcherCore"
    ),
    .executableTarget(
        name: "CodexConfigSwitcherCLI",
        dependencies: ["CodexConfigSwitcherCore"]
    ),
    .testTarget(
        name: "CodexConfigSwitcherCoreTests",
        dependencies: ["CodexConfigSwitcherCore"]
    ),
]

#if os(macOS)
products.insert(
    .executable(
        name: "CodexConfigSwitcher",
        targets: ["CodexConfigSwitcher"]
    ),
    at: 1
)

targets.insert(
    .executableTarget(
        name: "CodexConfigSwitcher",
        dependencies: ["CodexConfigSwitcherCore"]
    ),
    at: 1
)

targets.append(
    .testTarget(
        name: "CodexConfigSwitcherAppTests",
        dependencies: ["CodexConfigSwitcher", "CodexConfigSwitcherCore"]
    )
)

let package = Package(
    name: "CodexConfigSwitcher",
    platforms: [
        .macOS(.v13),
    ],
    products: products,
    targets: targets
)
#else
let package = Package(
    name: "CodexConfigSwitcher",
    products: products,
    targets: targets
)
#endif
