// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Ports",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "PortsLib",
            path: "Sources/PortsLib"
        ),
        .executableTarget(
            name: "Ports",
            dependencies: ["PortsLib"],
            path: "Sources/Ports"
        ),
        .testTarget(
            name: "PortsTests",
            dependencies: ["PortsLib"],
            path: "Tests/PortsTests"
        )
    ]
)
