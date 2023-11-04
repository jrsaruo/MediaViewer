//
//  MediaViewerDelegate.swift
//
//
//  Created by Yusaku Nishi on 2023/11/04.
//

import UIKit

@MainActor
public protocol MediaViewerDelegate: AnyObject {
    
    /// Tells the delegate an media viewer has moved to a particular page.
    /// - Parameters:
    ///   - mediaViewer: An media viewer informing the delegate about the page move.
    ///   - page: A destination page.
    func mediaViewer(_ mediaViewer: MediaViewerViewController, didMoveToPage page: Int)
}

// MARK: - Default implementations -

extension MediaViewerDelegate {
    public func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        didMoveToPage page: Int
    ) {}
}
