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
    /// - Note: `deleteAction` must complete deletion until it returns.
    ///         If the deletion fails, `deleteAction` can throw an error.
    /// - Parameter deleteAction: A closure that takes the current media identifier and
    ///                           performs the media deletion.
    ///                           It must complete deletion until it returns.
    /// - Returns: A trash button for deleting media.
    public func trashButton<MediaIdentifier>(
        deleteAction: @escaping (
            _ currentMediaIdentifier: MediaIdentifier
        ) async throws -> Void
    ) -> UIBarButtonItem where MediaIdentifier: Hashable {
        .init(systemItem: .trash, primaryAction: .init { [weak self] action in
            guard let self else { return }
            Task {
                try await deleteAction(self.currentMediaIdentifier())
                await self.reloadMedia()
            }
        })
    }
}
