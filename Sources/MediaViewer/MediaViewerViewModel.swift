//
//  MediaViewerViewModel.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/25.
//

import Combine
import class UIKit.UIPageViewController

final class MediaViewerViewModel: ObservableObject {
    
    /// Page identifiers of the media viewer.
    ///
    /// The page number corresponds to the index of this array.
    @Published var mediaIdentifiers: [AnyMediaIdentifier] = []
    
    @Published var showsMediaOnly = false
    
    // MARK: - Methods
    
    func mediaIdentifier(forPage page: Int) -> AnyMediaIdentifier? {
        guard 0 <= page && page < mediaIdentifiers.endIndex else { return nil }
        return mediaIdentifiers[page]
    }
    
    func page(with identifier: AnyMediaIdentifier) -> Int? {
        mediaIdentifiers.firstIndex(of: identifier)
    }
    
    func mediaIdentifier(
        before identifier: AnyMediaIdentifier
    ) -> AnyMediaIdentifier? {
        guard let page = page(with: identifier) else { return nil }
        let previousPage = page - 1
        return mediaIdentifier(forPage: previousPage)
    }
    
    func mediaIdentifier(
        after identifier: AnyMediaIdentifier
    ) -> AnyMediaIdentifier? {
        guard let page = page(with: identifier) else { return nil }
        let nextPage = page + 1
        return mediaIdentifier(forPage: nextPage)
    }
    
    func moveDirection(
        from currentIdentifier: AnyMediaIdentifier,
        to destinationIdentifier: AnyMediaIdentifier
    ) -> UIPageViewController.NavigationDirection {
        let currentPage = page(with: currentIdentifier)!
        let destinationPage = page(with: destinationIdentifier)!
        return destinationPage < currentPage ? .reverse : .forward
    }
}

// MARK: - Deletion -

extension MediaViewerViewModel {
    
    func deleteMediaIdentifier(_ identifier: AnyMediaIdentifier) {
        guard let page = page(with: identifier) else { return }
        mediaIdentifiers.remove(at: page)
    }
    
    func pagingAnimationAfterDeletion(
        deletingIdentifier: AnyMediaIdentifier,
        currentIdentifier: AnyMediaIdentifier
    ) -> (
        destinationIdentifier: AnyMediaIdentifier,
        direction: UIPageViewController.NavigationDirection?
    )? {
        guard deletingIdentifier == currentIdentifier else {
            // Stay on the current page
            return (
                destinationIdentifier: currentIdentifier,
                direction: nil
            )
        }
        
        let isDeletingLastPage = deletingIdentifier == mediaIdentifiers.last
        if isDeletingLastPage {
            guard let previousIdentifier = mediaIdentifier(before: deletingIdentifier) else {
                // When all pages are deleted, close the viewer and do not perform paging animation
                return nil
            }
            // Move back to the new last page
            return (destinationIdentifier: previousIdentifier, .reverse)
        } else {
            // Move to the next page
            guard let nextIdentifier = mediaIdentifier(after: deletingIdentifier) else { return nil }
            return (destinationIdentifier: nextIdentifier, .forward)
        }
    }
}
