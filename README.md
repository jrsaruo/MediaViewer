# template-swift-library

A template repository for Swift libraries.

## Requirements

- \<PLATFORM_VERSION\>
- \<SWIFT_VERSION\>

## Using \<LIBRARY_NAME\> in your project

To use the `<LIBRARY_NAME>` library in a SwiftPM project, add the following line to the dependencies in your `Package.swift` file:

```swift
.package(url: "https://github.com/jrsaruo/<LIBRARY_NAME>", from: "1.0.0"),
```

and add `<LIBRARY_NAME>` as a dependency for your target:

```swift
.target(name: "<target>", dependencies: [
    .product(name: "<LIBRARY_NAME>", package: "<PACKAGE_NAME>"),
    // other dependencies
]),
```

Finally, add `import <LIBRARY_NAME>` in your source code.
