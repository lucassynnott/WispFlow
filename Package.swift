// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WispFlow",
    platforms: [
        .macOS(.v14)  // WhisperKit requires macOS 14.0+
    ],
    products: [
        .executable(name: "WispFlow", targets: ["WispFlow"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "WispFlow",
            dependencies: ["WhisperKit"],
            path: "Sources/WispFlow"
        )
        // Note: Tests require full Xcode installation (not just Command Line Tools)
        // Tests can be added when building with Xcode IDE
    ]
)
