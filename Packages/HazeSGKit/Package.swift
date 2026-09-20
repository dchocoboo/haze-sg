// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HazeSGKit",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "HazeSGKit", targets: ["HazeSGKit"])
    ],
    targets: [
        .target(
            name: "HazeSGKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "HazeSGKitTests",
            dependencies: ["HazeSGKit"],
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
