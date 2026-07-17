// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BreakLock",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "BreakLock", targets: ["BreakLock"])
    ],
    targets: [
        .executableTarget(
            name: "BreakLock",
            path: "Sources/BreakLock",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
