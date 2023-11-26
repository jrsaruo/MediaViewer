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
    
    struct PagingAfterDeletion: Hashable {
        let destinationIdentifier: AnyMediaIdentifier
        let direction: UIPageViewController.NavigationDirection?
    }
    
    func paging(
        afterDeleting deletingIdentifiers: [AnyMediaIdentifier],
        currentIdentifier: AnyMediaIdentifier
    ) -> PagingAfterDeletion? {
        guard deletingIdentifiers.contains(currentIdentifier) else {
            // Stay on the current page
            return .init(
                destinationIdentifier: currentIdentifier,
                direction: nil
            )
        }
        
        let splitIdentifiers = mediaIdentifiers.split(
            separator: currentIdentifier,
            maxSplits: 2,
            omittingEmptySubsequences: false
        )
        let backwardIdentifiers = splitIdentifiers[0]
        let forwardIdentifiers = splitIdentifiers[1]
        
        if let nearestForward = forwardIdentifiers.first(where: {
            !deletingIdentifiers.contains($0)
        }) {
            return .init(
                destinationIdentifier: nearestForward,
                direction: .forward
            )
        } else if let nearestBackward = backwardIdentifiers.last(where: {
            !deletingIdentifiers.contains($0)
        }) {
            return .init(
                destinationIdentifier: nearestBackward,
                direction: .reverse
            )
        }
        
        // When all pages are deleted, close the viewer and do not perform paging animation
        return nil
    }
}
