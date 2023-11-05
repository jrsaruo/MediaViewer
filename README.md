# MediaViewer

A comfortable media viewer like the iOS standard.

## Requirements

- iOS 16+
- Swift 5.8+

## Using MediaViewer in your project

To use the `MediaViewer` library in a SwiftPM project, add the following line to the dependencies in your `Package.swift` file:

```swift
.package(url: "https://github.com/jrsaruo/MediaViewer", from: "1.0.0"),
```

and add `MediaViewer` as a dependency for your target:

```swift
.target(name: "<target>", dependencies: [
    .product(name: "MediaViewer", package: "MediaViewer"),
    // other dependencies
]),
```

Finally, add `import MediaViewer` in your source code.
