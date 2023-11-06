// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MediaViewer",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "MediaViewer",
            targets: ["MediaViewer"]
        ),
    ],
    targets: [
        .target(
            name: "MediaViewer",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "MediaViewerTests",
            dependencies: ["MediaViewer"]
        ),
    ]
)
