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
    
    func testPagingAnimation() {
        // Arrange
        let identifiers = (0..<5).map(AnyMediaIdentifier.init)
        mediaViewerVM.mediaIdentifiers = identifiers
        
        XCTContext.runActivity(
            named: "When the current page is deleted"
        ) { _ in
            XCTContext.runActivity(
                named: "When the forward page still exists, the viewer should move to the nearest forward page"
            ) { _ in
                // Act
                let animation = mediaViewerVM.pagingAnimation(
                    afterDeleting: Array(identifiers[2...3]),
                    currentIdentifier: identifiers[2]
                )
                
                // Assert
                XCTAssertEqual(
                    animation,
                    .init(
                        // Nearest forward page
                        destinationIdentifier: identifiers[4],
                        direction: .forward
                    )
                )
            }
            
            XCTContext.runActivity(
                named: "When all forward pages are deleted, the viewer should move back to the new last page"
            ) { _ in
                // Act
                let animation = mediaViewerVM.pagingAnimation(
                    afterDeleting: Array(identifiers[2...]),
                    currentIdentifier: identifiers[2]
                )
                
                // Assert
                XCTAssertEqual(
                    animation,
                    .init(
                        // New last page
                        destinationIdentifier: identifiers[1],
                        direction: .reverse
                    )
                )
            }
            
            XCTContext.runActivity(
                named: "When all pages are deleted, no animation is performed"
            ) { _ in
                // Act
                let animation = mediaViewerVM.pagingAnimation(
                    afterDeleting: identifiers,
                    currentIdentifier: identifiers[2]
                )
                
                // Assert
                XCTAssertNil(animation)
            }
        }
        
        XCTContext.runActivity(
            named: "When a non-current page is deleted, the viewer should stay on the current page"
        ) { _ in
            // Act
            let animation = mediaViewerVM.pagingAnimation(
                afterDeleting: [identifiers[1], identifiers[4]],
                currentIdentifier: identifiers[2]
            )
            
            // Assert
            XCTAssertEqual(
                animation,
                .init(
                    // Current page
                    destinationIdentifier: identifiers[2],
                    direction: nil
                )
            )
        }
    }
}
