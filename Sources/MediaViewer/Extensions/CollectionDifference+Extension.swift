//
//  CollectionDifference+Extension.swift
//
//
//  Created by Yusaku Nishi on 2023/11/21.
//

extension CollectionDifference.Change {
    
    var element: ChangeElement {
        switch self {
        case .insert(_, let element, _), .remove(_, let element, _):
            return element
        }
    }
}
