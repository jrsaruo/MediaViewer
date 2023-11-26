// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MediaViewer",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "MediaViewer",
            targets: ["MediaViewer"]
        ),
    ],
    targets: [
        .target(
            name: "MediaViewer"
        ),
        .testTarget(
            name: "MediaViewerTests",
            dependencies: ["MediaViewer"]
        ),
    ]
)
