// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "async-collections",
    platforms: [.macOS(.v12), .iOS(.v15), .tvOS(.v15), .watchOS(.v8)],
    products: [
        .library(name: "AsyncCollections", targets: ["AsyncCollections"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
    ],
    targets: [
        .target(name: "AsyncCollections", dependencies: [
            .product(name: "Collections", package: "swift-collections"),
        ]),
        .testTarget(name: "AsyncCollectionTests", dependencies: ["AsyncCollections"]),
    ]
)
