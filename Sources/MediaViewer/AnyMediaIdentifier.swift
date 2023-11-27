//
//  AnyMediaIdentifier.swift
//  
//
//  Created by Yusaku Nishi on 2023/11/27.
//

/// A type-erased media identifier.
struct AnyMediaIdentifier: Hashable {
    
    let base: AnyHashable
    
    init<MediaIdentifier>(
        _ base: MediaIdentifier
    ) where MediaIdentifier: Hashable {
        if let base = base as? AnyMediaIdentifier {
            assertionFailure("The base is already type-erased.")
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
