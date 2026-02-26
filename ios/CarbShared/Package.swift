// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CarbShared",
    platforms: [
        .iOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "CarbShared", targets: ["CarbShared"]),
    ],
    targets: [
        .target(name: "CarbShared"),
    ]
)
