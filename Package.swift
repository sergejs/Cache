// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Cache",
    platforms: [
        .macOS(.v12),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    products: [
        .library(
            name: "Cache",
            type: .dynamic,
            targets: ["Cache"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/sergejs/storable.git", from: "0.0.1"),
    ],
    targets: [
        .target(
            name: "Cache",
            dependencies: [
                .product(name: "Storable", package: "Storable"),
            ]
        ),
        .testTarget(
            name: "CacheTests",
            dependencies: ["Cache"]
        ),
    ]
)
