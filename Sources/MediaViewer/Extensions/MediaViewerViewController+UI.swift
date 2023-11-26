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
    /// If you want to provide your custom delete UI, you can build one with `deleteCurrentMedia(after:)` or `deleteMedia(with:after:)` instead.
    ///
    /// - Note: `deleteAction` must complete deletion until it returns.
    ///         That means the number of media must be reduced by one after the `deleteAction` is succeeded.
    ///         If the deletion fails, `deleteAction` must throw an error.
    /// - Parameter deleteAction: A closure that takes the current media identifier and
    ///                           performs the actual media deletion.
    ///                           It must complete deletion until it returns.
    /// - Returns: A trash button for deleting media.
    public func trashButton<MediaIdentifier>(
        deleteAction: @escaping (
            _ currentMediaIdentifier: MediaIdentifier
        ) async throws -> Void
    ) -> UIBarButtonItem where MediaIdentifier: Hashable {
        .init(systemItem: .trash, primaryAction: .init { [weak self] action in
            guard let self else { return }
            let button = action.sender as? UIBarButtonItem
            button?.isEnabled = false
            Task {
                defer { button?.isEnabled = true }
                try await self.deleteCurrentMedia(after: { currentMediaIdentifier in
                    try await deleteAction(currentMediaIdentifier)
                })
            }
        })
    }
}
