//
//  MediaViewerViewModel.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/25.
//

import Combine

final class MediaViewerViewModel: ObservableObject {
    
    /// Page identifiers of the media viewer.
    ///
    /// The page number corresponds to the index of this array.
    @Published var pageIDs: [MediaViewerPageID] = []
    
    @Published var showsMediaOnly = false
    
    // MARK: - Methods
    
    func setUpPageIDs(numberOfMedia: Int) {
        pageIDs = (0..<numberOfMedia).map { _ in .init() }
    }
    
    func pageID(forPage page: Int) -> MediaViewerPageID? {
        guard 0 <= page && page < pageIDs.endIndex else { return nil }
        return pageIDs[page]
    }
    
    func page(with pageID: MediaViewerPageID) -> Int? {
        pageIDs.firstIndex(of: pageID)
    }
}
