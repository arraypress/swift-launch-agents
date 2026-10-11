// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-launch-agents",
    // macOS only: launchd is the Mac's scheduler. No UI framework, so this
    // runs headless — which is the point of scheduling anything.
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "LaunchAgents", targets: ["LaunchAgents"]),
    ],
    targets: [
        .target(name: "LaunchAgents"),
        .testTarget(name: "LaunchAgentsTests", dependencies: ["LaunchAgents"]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
