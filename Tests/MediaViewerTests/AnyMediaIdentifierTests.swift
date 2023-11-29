//
//  AnyMediaIdentifierTests.swift
//
//
//  Created by Yusaku Nishi on 2023/11/28.
//

import XCTest
@testable import MediaViewer

final class AnyMediaIdentifierTests: XCTestCase {
    
    func testInit() {
        let identifier = AnyMediaIdentifier(1)
        XCTAssertEqual(AnyMediaIdentifier(identifier), identifier)
    }
    
    func testCasting() {
        let identifier = AnyMediaIdentifier("some identifier")
        XCTAssertEqual(identifier.as(String.self), "some identifier")
    }
}
