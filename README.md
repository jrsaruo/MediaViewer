# MediaViewer

A comfortable media viewer like the iOS standard.

![MediaViewerDemo](https://github.com/jrsaruo/MediaViewer/assets/23174349/6181382d-7b1f-4d79-8752-5ee9727fdef9)

## Requirements

- iOS 16+
- Swift 5.8+

## How to use

1. Make a type that conforms to `MediaViewerDataSource` protocol.

    ```swift
    extension YourViewController: MediaViewerDataSource {

        // var images: [UIImage]
        
        func numberOfMedia(in mediaViewer: MediaViewerViewController) -> Int {
            images.count
        }
        
        func mediaViewer(
            _ mediaViewer: MediaViewerViewController,
            mediaOnPage page: Int
        ) -> Media {
            .sync(images[page])
            // Or you can fetch an image asynchronously by using `.async { ... }`
        }

        func transitionSourceView(
            forCurrentPageOf mediaViewer: MediaViewerViewController
        ) -> UIView? {
            imageViews[mediaViewer.currentPage]
        }
    }
    ```
    
2. Create a `MediaViewerViewController` instance and push it. That's all! :tada:
    
    ```swift
    let openingPage = 0
    let mediaViewer = MediaViewerViewController(page: openingPage, dataSource: self)
    navigationController?.delegate = mediaViewer
    navigationController?.pushViewController(mediaViewer, animated: true)
    ```

See demo for more detailed usage.

## Using MediaViewer in your project

To use the `MediaViewer` library in a SwiftPM project, add the following line to the dependencies in your `Package.swift` file:

```swift
.package(url: "https://github.com/jrsaruo/MediaViewer", from: "0.0.1"),
```

and add `MediaViewer` as a dependency for your target:

```swift
.target(name: "<target>", dependencies: [
    .product(name: "MediaViewer", package: "MediaViewer"),
    // other dependencies
]),
```

Finally, add `import MediaViewer` in your source code.
