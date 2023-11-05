//
//  MediaViewerDelegate.swift
//
//
//  Created by Yusaku Nishi on 2023/11/04.
//

import UIKit

@MainActor
public protocol MediaViewerDelegate: AnyObject {
    
    /// Notifies the delegate before a media viewer is popped from the navigation controller.
    /// - Parameters:
    ///   - mediaViewer: A media viewer that will be popped.
    ///   - destinationVC: A destination view controller of the pop transition.
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        willBeginPopTransitionTo destinationVC: UIViewController
    )
    
    /// Tells the delegate a media viewer has moved to a particular page.
    /// - Parameters:
    ///   - mediaViewer: A media viewer informing the delegate about the page move.
    ///   - page: A destination page.
    func mediaViewer(_ mediaViewer: MediaViewerViewController, didMoveToPage page: Int)
}

// MARK: - Default implementations -

extension MediaViewerDelegate {
    
    public func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        willBeginPopTransitionTo destinationVC: UIViewController
    ) {}
    
    public func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        didMoveToPage page: Int
    ) {}
}
