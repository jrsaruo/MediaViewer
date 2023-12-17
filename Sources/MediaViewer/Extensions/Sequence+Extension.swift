//
//  Sequence+Extension.swift
//
//
//  Created by Yusaku Nishi on 2023/12/17.
//

extension Sequence {
    
    func subtracting(
        _ other: some Sequence<Element>
    ) -> [Element] where Element: Equatable {
        // TODO: Improve subtraction algorithm
        var subtracted: [Element] = []
        for element in self {
            if !other.contains(element) {
                subtracted.append(element)
            }
        }
        return subtracted
    }
    
    func subtracting2(
        _ other: some Sequence<Element>
    ) -> [Element] where Element: Hashable {
        Set(self).subtracting(Set(other))
    }
    
    func subtracting3(
        _ other: some Sequence<Element>
    ) -> [Element] where Element: Hashable {
        Set(self).subtracting(other)
    }
}
