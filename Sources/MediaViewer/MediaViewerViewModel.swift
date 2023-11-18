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
}
