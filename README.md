# ImageViewer

A comfortable image viewer like the iOS standard.

## Requirements

- \<PLATFORM_VERSION\>
- Swift 5.7+

## Using ImageViewer in your project

To use the `ImageViewer` library in a SwiftPM project, add the following line to the dependencies in your `Package.swift` file:

```swift
.package(url: "https://github.com/jrsaruo/ImageViewer", from: "1.0.0"),
```

and add `ImageViewer` as a dependency for your target:

```swift
.target(name: "<target>", dependencies: [
    .product(name: "ImageViewer", package: "ImageViewer"),
    // other dependencies
]),
```

Finally, add `import ImageViewer` in your source code.