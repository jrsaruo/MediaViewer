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

// MARK: - Reloading -

extension MediaViewerViewModel {
    
    struct PagingAfterReloading: Hashable {
        let destinationIdentifier: AnyMediaIdentifier
        let direction: UIPageViewController.NavigationDirection?
    }
    
    func paging(
        afterDeleting deletingIdentifiers: some Sequence<AnyMediaIdentifier>,
        currentIdentifier: AnyMediaIdentifier
    ) -> PagingAfterReloading? {
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
        
        // TODO: Prefer the recent paging direction
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

// MARK: - Page control bar interactive paging -

extension MediaViewerViewModel {
    
    enum PageControlBarInteractivePagingAction: Hashable {
        case start(forwards: Bool)
        case update(progress: Double)
        case finish
        case cancel
    }
    
    func pageControlBarInteractivePagingAction(
        on currentState: MediaViewerPageControlBar.State,
        scrollOffsetX: Double,
        scrollAreaWidth: Double
    ) -> PageControlBarInteractivePagingAction? {
        let progress0To2 = scrollOffsetX / scrollAreaWidth
        let isMovingToNextPage = progress0To2 > 1
        let rawProgress = isMovingToNextPage ? (progress0To2 - 1) : (1 - progress0To2)
        let progress = min(max(rawProgress, 0), 1)
        
        switch currentState {
        case .collapsing, .collapsed, .expanding, .expanded:
            // Prevent start when paging is finished and progress is reset to 0.
            guard progress != 0 else { return nil }
            return .start(forwards: isMovingToNextPage)
        case .transitioningInteractively(_, let forwards):
            if progress == 1 {
                return .finish
            } else if progress == 0 || forwards != isMovingToNextPage {
                // progress is 0 or direction is changed
                /*
                 NOTE:
                 Since the progress value sometimes jumps over zero,
                 the direction change is also checked.
                 */
                return .cancel
            } else {
                return .update(progress: progress)
            }
        case .reloading:
            return nil
        }
    }
}
