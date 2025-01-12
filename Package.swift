// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Jsum",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        .library(
            name: "Jsum",
            targets: ["Jsum"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Azoy/Echo.git", .branch("main"))
    ],
    targets: [
        .target(
            name: "Jsum",
            dependencies: ["Echo"],
            path: "Sources"
        ),
        .testTarget(
            name: "JsumTests",
            dependencies: ["Jsum"],
            path: "Tests"
        )
    ]
)

