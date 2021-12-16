// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Cache",
    platforms: [
        .macOS(.v10_15),
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
        .package(url: "https://github.com/sergejs/Storable.git", .upToNextMajor(from: "0.2.0")),
        .package(url: "https://github.com/sergejs/ServiceContainer.git", .upToNextMajor(from: "0.2.0")),
    ],
    targets: [
        .target(
            name: "Cache",
            dependencies: [
                .product(name: "Storable", package: "Storable"),
                .product(name: "ServiceContainer", package: "ServiceContainer"),
            ]
        ),
        .testTarget(
            name: "CacheTests",
            dependencies: ["Cache"]
        ),
    ]
)
