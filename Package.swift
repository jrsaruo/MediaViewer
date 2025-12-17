// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MediaViewer",
    platforms: [
        .iOS(.v16),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "MediaViewer",
            targets: ["MediaViewer"],
        ),
    ],
    targets: [
        .target(
            name: "MediaViewer",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
            ],
        ),
        .testTarget(
            name: "MediaViewerTests",
            dependencies: ["MediaViewer"],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
            ],
        ),
    ]
)
