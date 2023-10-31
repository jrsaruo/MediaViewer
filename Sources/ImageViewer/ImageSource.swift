//
//  ImageSource.swift
//
//
//  Created by Yusaku Nishi on 2023/10/31.
//

import UIKit

/// The way to animate the image transition.
public enum ImageTransition: Hashable, Sendable {
    
    /// The fade animation with the specified duration.
    case fade(duration: TimeInterval)
    
    /// No animation.
    case none
}

/// The image source for the image viewer.
public enum ImageSource {
    
    /// An image that can be acquired synchronously.
    case sync(UIImage?)
    
    /// An image that can be acquired asynchronously.
    ///
    /// The viewer will use `provider` to acquire an image and display it using `transition`.
    case async(
        transition: ImageTransition = .fade(duration: 0.2),
        provider: @Sendable () async -> UIImage?
    )
    
    /// An image source that represents the lack of an image.
    ///
    /// This is equivalent to `.sync(nil)`.
    static var none: Self { .sync(nil) }
}
