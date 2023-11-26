//
//  CollectionDifference+Extension.swift
//
//
//  Created by Yusaku Nishi on 2023/11/21.
//

extension CollectionDifference {
    
    typealias ChangeAssociatedValues = (
        offset: Int,
        element: ChangeElement,
        associatedWith: Int?
    )
    
    var changes: (
        insertions: [ChangeAssociatedValues],
        removals: [ChangeAssociatedValues]
    ) {
        var insertions: [ChangeAssociatedValues] = []
        var removals: [ChangeAssociatedValues] = []
        for change in self {
            switch change {
            case .insert(let offset, let element, let associatedWith):
                insertions.append((offset, element, associatedWith))
            case .remove(let offset, let element, let associatedWith):
                removals.append((offset, element, associatedWith))
            }
        }
        return (insertions: insertions, removals: removals)
    }
}
