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
    
    func testPagingAfterReloading() {
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
                let pagingAfterReloading = mediaViewerVM.paging(
                    afterDeleting: Array(identifiers[2...3]),
                    currentIdentifier: identifiers[2],
                    finalIdentifiers: [identifiers[0], identifiers[1], identifiers[4]]
                )
                
                // Assert
                XCTAssertEqual(
                    pagingAfterReloading,
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
                let pagingAfterReloading = mediaViewerVM.paging(
                    afterDeleting: Array(identifiers[2...]),
                    currentIdentifier: identifiers[2],
                    finalIdentifiers: [identifiers[0], identifiers[1]]
                )
                
                // Assert
                XCTAssertEqual(
                    pagingAfterReloading,
                    .init(
                        // New last page
                        destinationIdentifier: identifiers[1],
                        direction: .reverse
                    )
                )
            }
            
            XCTContext.runActivity(
                named: "When all pages are deleted, nothing happens"
            ) { _ in
                // Act
                let pagingAfterReloading = mediaViewerVM.paging(
                    afterDeleting: identifiers,
                    currentIdentifier: identifiers[2],
                    finalIdentifiers: []
                )
                
                // Assert
                XCTAssertNil(pagingAfterReloading)
            }
        }
        
        XCTContext.runActivity(
            named: "When the current page is not deleted, the viewer should stay on the current page"
        ) { _ in
            XCTContext.runActivity(
                named: "When some non-current pages are deleted"
            ) { _ in
                // Act
                let pagingAfterReloading = mediaViewerVM.paging(
                    afterDeleting: [identifiers[1], identifiers[4]],
                    currentIdentifier: identifiers[2],
                    finalIdentifiers: [identifiers[0], identifiers[2], identifiers[3]]
                )
                
                // Assert
                XCTAssertEqual(
                    pagingAfterReloading,
                    .init(
                        // Current page
                        destinationIdentifier: identifiers[2],
                        direction: nil
                    )
                )
            }
            
            XCTContext.runActivity(
                named: "When no pages are deleted"
            ) { _ in
                // Act
                let pagingAfterReloading = mediaViewerVM.paging(
                    afterDeleting: [],
                    currentIdentifier: identifiers[2],
                    finalIdentifiers: identifiers.reversed()
                )
                
                // Assert
                XCTAssertEqual(
                    pagingAfterReloading,
                    .init(
                        // Current page
                        destinationIdentifier: identifiers[2],
                        direction: nil
                    )
                )
            }
        }
    }
}
