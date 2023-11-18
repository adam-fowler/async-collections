// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency=complete")
]

let package = Package(
    name: "async-collections",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "AsyncCollections", targets: ["AsyncCollections"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "AsyncCollections",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "Collections", package: "swift-collections"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AsyncCollectionTests",
            dependencies: ["AsyncCollections"],
            swiftSettings: swiftSettings
        ),
    ]
)
