# MediaViewer

A comfortable media viewer like the iOS standard.

![MediaViewerDemo](https://github.com/jrsaruo/MediaViewer/assets/23174349/6181382d-7b1f-4d79-8752-5ee9727fdef9) ![MediaViewerDemo _camera](https://github.com/jrsaruo/MediaViewer/assets/23174349/efc2b713-ac2f-4c36-8e9f-69b612281e0c)

## Requirements

- iOS 16+
- Swift 5.8+

## How to use

1. Make a type that conforms to `MediaViewerDataSource` protocol.

    ```swift
    extension YourViewController: MediaViewerDataSource {
        
        // You can specify any type that conforms to `Hashable`.
        typealias MediaIdentifier = UIImage
        
        // var images: [UIImage]
        
        func mediaIdentifiers(
            for mediaViewer: MediaViewerViewController
        ) -> [MediaIdentifier] {
            images
        }
        
        func mediaViewer(
            _ mediaViewer: MediaViewerViewController,
            mediaWith mediaIdentifier: MediaIdentifier // UIImage
        ) -> Media {
            .sync(mediaIdentifier)
            // Or you can fetch media asynchronously by `.async { ... }`
        }
        
        func mediaViewer(
            _ mediaViewer: MediaViewerViewController,
            transitionSourceViewForMediaWith mediaIdentifier: MediaIdentifier
        ) -> UIView? {
            // Return a view that is animated when the viewer opens or closes.
            imageView(for: mediaIdentifier)
        }
    }
    ```
    
2. Create a `MediaViewerViewController` instance and push it. That's all! :tada:
    
    ```swift
    let mediaViewer = MediaViewerViewController(opening: image, dataSource: self)
    navigationController?.delegate = mediaViewer
    navigationController?.pushViewController(mediaViewer, animated: true)
    ```

See demo for more detailed usage.

## Using MediaViewer in your project

To use the `MediaViewer` library in a SwiftPM project, add the following line to the dependencies in your `Package.swift` file:

```swift
.package(url: "https://github.com/jrsaruo/MediaViewer", from: "0.1.0"),
```

and add `MediaViewer` as a dependency for your target:

```swift
.target(name: "<target>", dependencies: [
    .product(name: "MediaViewer", package: "MediaViewer"),
    // other dependencies
]),
```

Finally, add `import MediaViewer` in your source code.
