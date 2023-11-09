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
}
