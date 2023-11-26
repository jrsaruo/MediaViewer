//
//  MediaViewerViewModelTests.swift
//
//
//  Created by Yusaku Nishi on 2023/11/10.
//

import XCTest
@testable import MediaViewer

final class MediaViewerViewModelTests: XCTestCase {
    
    private var mediaViewerVM: MediaViewerViewModel!
    
    override func setUp() {
        mediaViewerVM = .init()
    }
    
    func testPagingAnimationAfterDeletion() throws {
        // Arrange
        let identifiers = (0..<5).map(AnyMediaIdentifier.init)
        
        try XCTContext.runActivity(
            named: "When the current page is deleted"
        ) { _ in
            try XCTContext.runActivity(
                named: "When the non-last page is deleted, forward animation is performed"
            ) { _ in
                // Arrange
                mediaViewerVM.mediaIdentifiers = identifiers
                
                // Act
                let animation = mediaViewerVM.pagingAnimationAfterDeletion(
                    deletingIdentifier: identifiers[3],
                    currentIdentifier: identifiers[3]
                )
                
                // Assert
                let (destination, direction) = try XCTUnwrap(animation)
                XCTAssertEqual(destination, identifiers[4]) // Next page
                XCTAssertEqual(direction, .forward)
            }
            
            try XCTContext.runActivity(
                named: "When the last page is deleted, reverse animation is performed"
            ) { _ in
                // Arrange
                mediaViewerVM.mediaIdentifiers = identifiers
                
                // Act
                let animation = mediaViewerVM.pagingAnimationAfterDeletion(
                    deletingIdentifier: identifiers.last!,
                    currentIdentifier: identifiers.last!
                )
                
                // Assert
                let (destination, direction) = try XCTUnwrap(animation)
                XCTAssertEqual(destination, identifiers[3]) // Previous page
                XCTAssertEqual(direction, .reverse)
            }
            
            XCTContext.runActivity(
                named: "When all pages are deleted, no animation is performed"
            ) { _ in
                // Arrange
                mediaViewerVM.mediaIdentifiers = [identifiers[0]]
                
                // Act
                let animation = mediaViewerVM.pagingAnimationAfterDeletion(
                    deletingIdentifier: identifiers[0],
                    currentIdentifier: identifiers[0]
                )
                
                // Assert
                XCTAssertNil(animation)
            }
        }
        
        try XCTContext.runActivity(
            named: "When a non-current page is deleted, the page is kept"
        ) { _ in
            // Arrange
            mediaViewerVM.mediaIdentifiers = identifiers
            
            // Act
            let animation = mediaViewerVM.pagingAnimationAfterDeletion(
                deletingIdentifier: identifiers[1],
                currentIdentifier: identifiers[3]
            )
            
            // Assert
            let (destination, direction) = try XCTUnwrap(animation)
            XCTAssertEqual(destination, identifiers[3])
            XCTAssertNil(direction)
        }
    }
}
