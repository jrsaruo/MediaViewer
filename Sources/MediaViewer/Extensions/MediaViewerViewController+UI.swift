//
//  MediaViewerViewController+UI.swift
//
//
//  Created by Yusaku Nishi on 2023/11/08.
//

import UIKit

extension MediaViewerViewController {
    
    /// Creates and returns a trash button for deleting media on the current page.
    ///
    /// If you want to provide your custom delete UI, you can build one with `reloadMedia()`
    /// method instead.
    ///
    /// - Parameters:
    ///   - animatingDeletion: Whether to animate the media deletion.
    ///   - deleteAction: A closure that performs the media deletion.
    ///                   It takes the viewer, button itself and the current media identifier.
    /// - Note: `deleteAction` must complete deletion until it returns.
    /// - Returns: A trash button for deleting media.
    public func trashButton<MediaIdentifier>(
        animatingDeletion: Bool = true,
        deleteAction: @escaping (
            _ mediaViewer: MediaViewerViewController,
            _ trashButton: UIBarButtonItem,
            _ currentMediaIdentifier: MediaIdentifier
        ) async -> Void
    ) -> UIBarButtonItem where MediaIdentifier: Hashable {
        let button = UIBarButtonItem(systemItem: .trash)
        button.primaryAction = .init { [weak self] action in
            guard let self else { return }
            Task {
                await deleteAction(
                    self,
                    button,
                    self.currentMediaIdentifier()
                )
                await self.reloadMedia(animated: animatingDeletion)
            }
        }
        return button
    }
}
