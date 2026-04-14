// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FileSandboxMenuBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "FileSandboxMenuBar",
            path: "Sources/App"
        ),
    ]
)
