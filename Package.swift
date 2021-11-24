// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Cache",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "Cache",
            type: .dynamic,
            targets: ["Cache"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/sergejs/Storable.git", .branch("main")),
        .package(url: "https://github.com/sergejs/ServiceContainer.git", .branch("main")),
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
