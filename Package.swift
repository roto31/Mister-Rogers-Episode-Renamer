// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MisterRogersRenamer",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "MisterRogersRenamerCore", targets: ["MisterRogersRenamerCore"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MisterRogersRenamerCore",
            dependencies: [],
            path: "Sources/MisterRogersRenamerCore",
            resources: [
                .copy("Resources/episodes.json"),
                .copy("Resources/episodes.manifest.json"),
            ]
        ),
        .testTarget(
            name: "MisterRogersRenamerTests",
            dependencies: ["MisterRogersRenamerCore"],
            path: "Tests/MisterRogersRenamerTests"
        ),
    ]
)
