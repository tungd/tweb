// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "tweb",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "tweb", targets: ["tweb"]),
        .library(name: "TwebCore", targets: ["TwebCore"])
    ],
    targets: [
        .target(
            name: "TwebCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "tweb",
            dependencies: ["TwebCore"]
        ),
        .testTarget(
            name: "TwebCoreTests",
            dependencies: ["TwebCore"]
        )
    ]
)
