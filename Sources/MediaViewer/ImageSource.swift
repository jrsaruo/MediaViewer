//
//  ImageSource.swift
//
//
//  Created by Yusaku Nishi on 2023/10/31.
//

import UIKit

/// The way to animate media transition.
public enum MediaTransition: Hashable, Sendable {
    
    /// The fade animation with the specified duration.
    case fade(duration: TimeInterval)
    
    /// No animation.
    case none
}

/// The source for the media viewer.
public enum Source<Resource> {
    
    /// A resource that can be acquired synchronously.
    case sync(Resource)
    
    /// A resource that can be acquired asynchronously.
    ///
    /// The viewer will use `provider` to acquire a resource and display it using `transition`.
    case async(
        transition: MediaTransition = .fade(duration: 0.2),
        provider: @Sendable () async -> Resource
    )
}

extension Source: Sendable where Resource: Sendable {}

extension Source where Resource: ExpressibleByNilLiteral {
    
    /// A source that represents the lack of a resource.
    ///
    /// This is equivalent to `.sync(nil)`.
    static var none: Self { .sync(nil) }
}

/// The image source for the media viewer.
public typealias ImageSource = Source<UIImage?>

// MARK: - Media -

/// The media source for the media viewer.
public enum Media: Sendable {
    case image(ImageSource)
}

// MARK: - Convenience methods to create Media

extension Media {
    
    /// An image that can be acquired synchronously.
    public static func sync(_ image: UIImage?) -> Self {
        .image(.sync(image))
    }
    
    /// An image that can be acquired asynchronously.
    ///
    /// The viewer will use `provider` to acquire an image and display it using `transition`.
    public static func async(
        transition: MediaTransition = .fade(duration: 0.2),
        provider: @escaping @Sendable () async -> UIImage?
    ) -> Self {
        .image(.async(transition: transition, provider: provider))
    }
}
