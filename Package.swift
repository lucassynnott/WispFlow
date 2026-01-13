// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WispFlow",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WispFlow", targets: ["WispFlow"])
    ],
    targets: [
        .executableTarget(
            name: "WispFlow",
            path: "Sources/WispFlow"
        )
        // Note: Tests require full Xcode installation (not just Command Line Tools)
        // Tests can be added when building with Xcode IDE
    ]
)
