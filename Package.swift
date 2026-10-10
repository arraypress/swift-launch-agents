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
