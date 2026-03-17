// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OneClient",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "OneClient", targets: ["OneClient"]),
        .executable(name: "OneClientChecks", targets: ["OneClientChecks"]),
        .executable(name: "OneAppHost", targets: ["OneAppHost"])
    ],
    targets: [
        .target(
            name: "OneClient",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(name: "OneClientChecks", dependencies: ["OneClient"]),
        .executableTarget(name: "OneAppHost", dependencies: ["OneClient"])
    ]
)
