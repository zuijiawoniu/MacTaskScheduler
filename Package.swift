// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MacTaskScheduler",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacTaskScheduler", targets: ["MacTaskScheduler"])
    ],
    targets: [
        .executableTarget(
            name: "MacTaskScheduler"
        )
    ]
)
