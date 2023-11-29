//
//  MediaViewerDelegate.swift
//
//
//  Created by Yusaku Nishi on 2023/11/04.
//

import UIKit

@MainActor
public protocol MediaViewerDelegate<MediaIdentifier>: AnyObject {
    
    associatedtype MediaIdentifier: Hashable
    
    /// Notifies the delegate before a media viewer is popped from the navigation controller.
    /// - Parameters:
    ///   - mediaViewer: A media viewer that will be popped.
    ///   - destinationVC: A destination view controller of the pop transition.
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        willBeginPopTransitionTo destinationVC: UIViewController
    )
    
    /// Tells the delegate a media viewer has moved to some media page.
    /// - Parameters:
    ///   - mediaViewer: A media viewer informing the delegate about the page move.
    ///   - mediaIdentifier: An identifier for media on a destination page.
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        didMoveToMediaWith mediaIdentifier: MediaIdentifier
    )
}

// MARK: - Default implementations -

extension MediaViewerDelegate {
    
    public func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        willBeginPopTransitionTo destinationVC: UIViewController
    ) {}
    
    public func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        didMoveToMediaWith mediaIdentifier: MediaIdentifier
    ) {}
}

// MARK: - Type erasure support -

extension MediaViewerDelegate {
    
    func verifyMediaIdentifierTypeIsSame<DataSourceMediaIdentifier>(
        as dataSource: some MediaViewerDataSource<DataSourceMediaIdentifier>
    ) {
        precondition(
            MediaIdentifier.self == DataSourceMediaIdentifier.self,
            "`MediaIdentifier` must be \(DataSourceMediaIdentifier.self), the same as the data source, but it is actually \(MediaIdentifier.self)."
        )
    }
    
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        didMoveToMediaWith mediaIdentifier: AnyMediaIdentifier
    ) {
        self.mediaViewer(
            mediaViewer,
            didMoveToMediaWith: mediaIdentifier.as(MediaIdentifier.self)
        )
    }
}
