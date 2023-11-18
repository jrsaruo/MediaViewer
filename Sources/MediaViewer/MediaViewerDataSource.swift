//
//  MediaViewerDataSource.swift
//
//
//  Created by Yusaku Nishi on 2023/11/04.
//

import UIKit

/// The object you use to provide data for an media viewer.
@MainActor
public protocol MediaViewerDataSource<MediaIdentifier>: AnyObject {
    
    /// A type representing the unique identifier for media.
    associatedtype MediaIdentifier: Hashable
    
    /// Asks the data source to return all identifiers for media to view in the media viewer.
    /// - Parameter mediaViewer: An object representing the media viewer requesting this information.
    /// - Returns: All identifiers for media to view in the `mediaViewer`.
    func mediaIdentifiers(
        for mediaViewer: MediaViewerViewController
    ) -> [MediaIdentifier]
    
    /// Asks the data source to return media with the specified identifier to view in the media viewer.
    /// - Parameters:
    ///   - mediaViewer: An object representing the media viewer requesting this information.
    ///   - mediaIdentifier: An identifier for media.
    /// - Returns: Media with `mediaIdentifier` to view in `mediaViewer`.
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        mediaWith mediaIdentifier: MediaIdentifier
    ) -> Media
    
    /// Asks the data source to return an aspect ratio of media with the specified identifier.
    ///
    /// The ratio will be used to determine a size of page thumbnail.
    /// This method should return immediately.
    ///
    /// - Parameters:
    ///   - mediaViewer: An object representing the media viewer requesting this information.
    ///   - mediaIdentifier: An identifier for media.
    /// - Returns: An aspect ratio of media with `mediaIdentifier`.
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        widthToHeightOfMediaWith mediaIdentifier: MediaIdentifier
    ) -> CGFloat?
    
    /// Asks the data source to return a source of a thumbnail image on the page control bar in the media viewer.
    /// - Parameters:
    ///   - mediaViewer: An object representing the media viewer requesting this information.
    ///   - mediaIdentifier: An identifier for media.
    ///   - preferredThumbnailSize: An expected size of the thumbnail image. For better performance, it is preferable to shrink the thumbnail image to a size that fills this size.
    /// - Returns: A source of a thumbnail image on the page control bar in `mediaViewer`.
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        pageThumbnailForMediaWith mediaIdentifier: MediaIdentifier,
        filling preferredThumbnailSize: CGSize
    ) -> Source<UIImage?>
    
    /// Asks the data source to return the transition source view for media currently viewed in the viewer.
    ///
    /// The media viewer uses this view for push or pop transitions.
    /// On the push transition, an animation runs as the image expands from this view. The reverse happens on the pop.
    ///
    /// If `nil`, the animation looks like cross-dissolve.
    ///
    /// - Parameter mediaViewer: An object representing the media viewer requesting this information.
    /// - Returns: The transition source view for current media of `mediaViewer`.
    func transitionSourceView(
        forCurrentMediaOf mediaViewer: MediaViewerViewController
    ) -> UIView?
    
    /// Asks the data source to return the transition source image for current media of the viewer.
    ///
    /// The media viewer uses this image for the push transition if needed.
    /// If the viewer has not yet acquired an image asynchronously at the start of the push transition,
    /// the viewer starts a transition animation with this image.
    ///
    /// - Parameters:
    ///   - mediaViewer: An object representing the media viewer requesting this information.
    ///   - sourceView: A transition source view that is returned from `transitionSourceView(forCurrentMediaOf:)` method.
    /// - Returns: The transition source image for current media of `mediaViewer`.
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        transitionSourceImageWith sourceView: UIView?
    ) -> UIImage?
}

// MARK: - Default implementations -

extension MediaViewerDataSource {
    
    public func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        widthToHeightOfMediaWith mediaIdentifier: MediaIdentifier
    ) -> CGFloat? {
        let media = self.mediaViewer(mediaViewer, mediaWith: mediaIdentifier)
        switch media {
        case .image(.sync(let image?)) where image.size.height > 0:
            return image.size.width / image.size.height
        case .image(.sync), .image(.async):
            return nil
        }
    }
    
    public func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        pageThumbnailForMediaWith mediaIdentifier: MediaIdentifier,
        filling preferredThumbnailSize: CGSize
    ) -> Source<UIImage?> {
        let media = self.mediaViewer(mediaViewer, mediaWith: mediaIdentifier)
        switch media {
        case .image(.sync(let image)):
            return .sync(
                image?.preparingThumbnail(of: preferredThumbnailSize) ?? image
            )
        case .image(.async(let transition, let imageProvider)):
            return .async(transition: transition) {
                let image = await imageProvider()
                return await image?.byPreparingThumbnail(
                    ofSize: preferredThumbnailSize
                ) ?? image
            }
        }
    }
    
    public func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        transitionSourceImageWith sourceView: UIView?
    ) -> UIImage? {
        switch sourceView {
        case let sourceImageView as UIImageView:
            return sourceImageView.image
        default:
            return nil
        }
    }
}

// MARK: - Open existential types -

extension MediaViewerDataSource {
    
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        mediaWith mediaIdentifier: AnyMediaIdentifier
    ) -> Media {
        self.mediaViewer(
            mediaViewer,
            mediaWith: mediaIdentifier.rawValue as! MediaIdentifier
        )
    }
    
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        widthToHeightOfMediaWith mediaIdentifier: AnyMediaIdentifier
    ) -> CGFloat? {
        self.mediaViewer(
            mediaViewer,
            widthToHeightOfMediaWith: mediaIdentifier.rawValue as! MediaIdentifier
        )
    }
    
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        pageThumbnailForMediaWith mediaIdentifier: AnyMediaIdentifier,
        filling preferredThumbnailSize: CGSize
    ) -> Source<UIImage?> {
        self.mediaViewer(
            mediaViewer,
            pageThumbnailForMediaWith: mediaIdentifier.rawValue as! MediaIdentifier,
            filling: preferredThumbnailSize
        )
    }
}
