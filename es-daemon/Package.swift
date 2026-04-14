// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ESWatcher",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "ESWatcher",
            path: "Sources/ESWatcher",
            linkerSettings: [
                .linkedLibrary("EndpointSecurity"),
            ]
        ),
    ]
)
