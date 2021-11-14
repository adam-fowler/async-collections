// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "asyncPatterns",
    platforms: [.macOS(.v12), .iOS(.v15), .tvOS(.v15), .watchOS(.v8)],
    products: [
        .library(name: "asyncPatterns", targets: ["asyncPatterns"]),
    ],
    targets: [
        .target(name: "asyncPatterns"),
        .testTarget(name: "asyncPatternTests", dependencies: ["asyncPatterns"]),
    ]
)
