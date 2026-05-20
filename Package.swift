// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LimitLens",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "LimitLens", targets: ["LimitLens"]),
        .library(name: "LimitLensCore", targets: ["LimitLensCore"])
    ],
    targets: [
        .target(
            name: "LimitLensCore",
            linkerSettings: [.linkedFramework("Security")]
        ),
        .executableTarget(name: "LimitLens", dependencies: ["LimitLensCore"]),
        .testTarget(name: "LimitLensCoreTests", dependencies: ["LimitLensCore"])
    ]
)
