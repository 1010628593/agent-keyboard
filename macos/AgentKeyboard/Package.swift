// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentKeyboard",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "AgentKeyboardCore", targets: ["AgentKeyboardCore"]),
        .executable(name: "AgentKeyboard", targets: ["AgentKeyboardApp"]),
    ],
    targets: [
        .target(
            name: "AgentKeyboardCore",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("Network"),
            ]
        ),
        .executableTarget(
            name: "AgentKeyboardApp",
            dependencies: ["AgentKeyboardCore"],
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
            ]
        ),
        .testTarget(
            name: "AgentKeyboardCoreTests",
            dependencies: ["AgentKeyboardCore"]
        ),
    ]
)
