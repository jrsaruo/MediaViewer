//
//  AnyMediaIdentifier.swift
//  
//
//  Created by Yusaku Nishi on 2023/11/27.
//

/// A type-erased media identifier.
struct AnyMediaIdentifier: Hashable, @unchecked Sendable {
    
    let base: AnyHashable // This must be Sendable
    
    init<MediaIdentifier>(
        _ base: MediaIdentifier
    ) where MediaIdentifier: Hashable & Sendable {
        if let base = base as? AnyMediaIdentifier {
            // Already type-erased
            self = base
            return
        }
        self.base = base
    }
    
    func `as`<MediaIdentifier>(
        _ identifierType: MediaIdentifier.Type
    ) -> MediaIdentifier {
        guard let identifier = base as? MediaIdentifier else {
            preconditionFailure(
                "The type of media identifier is \(type(of: base.base)), not \(identifierType)."
            )
        }
        return identifier
    }
}
