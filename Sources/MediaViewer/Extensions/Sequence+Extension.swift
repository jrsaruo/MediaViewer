//
//  Sequence+Extension.swift
//
//
//  Created by Yusaku Nishi on 2023/12/17.
//

extension Sequence where Element: Hashable {
    
    func subtracting(_ other: some Sequence<Element>) -> Set<Element> {
        Set(self).subtracting(Set(other))
    }
}
