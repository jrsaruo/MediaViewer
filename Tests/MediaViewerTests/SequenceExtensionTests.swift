//
//  SequenceExtensionTests.swift
//
//
//  Created by Yusaku Nishi on 2023/12/17.
//

import XCTest
@testable import MediaViewer

final class SequenceExtensionTests: XCTestCase {
    
    func testSubtraction() {
        XCTAssertEqual([0, 1, 2].subtracting([0, 1, 2, 3]), [])
        XCTAssertEqual([0, 1, 2].subtracting([0, 1, 2]), [])
        XCTAssertEqual([0, 1, 2].subtracting([0, 1]), [2])
        XCTAssertEqual([0, 1, 2].subtracting([1]), [0, 2])
        XCTAssertEqual([0, 1, 2].subtracting([]), [0, 1, 2])
        XCTAssertEqual([0, 1, 2].subtracting([100]), [0, 1, 2])
    }
    
    func testMeasureSubtracting() {
        measure {
            _ = (0..<3000).subtracting(
                stride(from: 0, to: 3000, by: 1)
            )
        }
    }
}
