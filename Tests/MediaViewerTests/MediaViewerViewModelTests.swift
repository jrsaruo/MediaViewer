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
    
    // MARK: Reloading tests
    
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
                    currentIdentifier: identifiers[2]
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
                    currentIdentifier: identifiers[2]
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
                    currentIdentifier: identifiers[2]
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
                    currentIdentifier: identifiers[2]
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
                    currentIdentifier: identifiers[2]
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
    
    // MARK: Page control bar interactive paging tests
    
    private typealias InteractivePagingTestCase = (
        scrollOffsetX: Double,
        scrollAreaWidth: Double,
        expected: MediaViewerViewModel.PageControlBarInteractivePagingAction?,
        line: UInt
    )
    
    func testInteractivePagingOnExpanded() {
        // Arrange
        let testCases: [InteractivePagingTestCase] = [
            (
                scrollOffsetX: 400.1,
                scrollAreaWidth: 400,
                expected: .start(forwards: true),
                line: #line
            ),
            (
                scrollOffsetX: 399.9,
                scrollAreaWidth: 400,
                expected: .start(forwards: false),
                line: #line
            ),
            (
                scrollOffsetX: 400,
                scrollAreaWidth: 400,
                expected: nil,
                line: #line
            )
        ]
        
        for testCase in testCases {
            // Act
            let action = mediaViewerVM.pageControlBarInteractivePagingAction(
                on: .expanded,
                scrollOffsetX: testCase.scrollOffsetX,
                scrollAreaWidth: testCase.scrollAreaWidth
            )
            
            // Assert
            XCTAssertEqual(action, testCase.expected, line: testCase.line)
        }
    }
    
    func testInteractivePagingOnTransitioningToNextPage() {
        // Arrange
        let testCases: [InteractivePagingTestCase] = [
            (
                // In progress
                scrollOffsetX: 500,
                scrollAreaWidth: 400,
                expected: .update(progress: 0.25),
                line: #line
            ),
            (
                // Reached the next page
                scrollOffsetX: 800,
                scrollAreaWidth: 400,
                expected: .finish,
                line: #line
            ),
            (
                // Came back to the current page
                scrollOffsetX: 400,
                scrollAreaWidth: 400,
                expected: .cancel,
                line: #line
            ),
            (
                // Changed the paging direction
                scrollOffsetX: 399.9,
                scrollAreaWidth: 400,
                expected: .cancel,
                line: #line
            )
        ]
        let dummyLayout = UICollectionViewTransitionLayout(
            currentLayout: .init(),
            nextLayout: .init()
        )
        
        for testCase in testCases {
            // Act
            let action = mediaViewerVM.pageControlBarInteractivePagingAction(
                on: .transitioningInteractively(dummyLayout, forwards: true),
                scrollOffsetX: testCase.scrollOffsetX,
                scrollAreaWidth: testCase.scrollAreaWidth
            )
            
            // Assert
            XCTAssertEqual(action, testCase.expected, line: testCase.line)
        }
    }
    
    func testInteractivePagingOnTransitioningToPreviousPage() {
        // Arrange
        let testCases: [InteractivePagingTestCase] = [
            (
                // In progress
                scrollOffsetX: 300,
                scrollAreaWidth: 400,
                expected: .update(progress: 0.25),
                line: #line
            ),
            (
                // Reached the previous page
                scrollOffsetX: 0,
                scrollAreaWidth: 400,
                expected: .finish,
                line: #line
            ),
            (
                // Came back to the current page
                scrollOffsetX: 400,
                scrollAreaWidth: 400,
                expected: .cancel,
                line: #line
            ),
            (
                // Changed the paging direction
                scrollOffsetX: 400.1,
                scrollAreaWidth: 400,
                expected: .cancel,
                line: #line
            )
        ]
        let dummyLayout = UICollectionViewTransitionLayout(
            currentLayout: .init(),
            nextLayout: .init()
        )
        
        for testCase in testCases {
            // Act
            let action = mediaViewerVM.pageControlBarInteractivePagingAction(
                on: .transitioningInteractively(dummyLayout, forwards: false),
                scrollOffsetX: testCase.scrollOffsetX,
                scrollAreaWidth: testCase.scrollAreaWidth
            )
            
            // Assert
            XCTAssertEqual(action, testCase.expected, line: testCase.line)
        }
    }
    
    func testInteractivePagingOnReloading() {
        // Arrange
        let testCases: [InteractivePagingTestCase] = [
            (
                scrollOffsetX: 0,
                scrollAreaWidth: 400,
                expected: nil,
                line: #line
            ),
            (
                scrollOffsetX: 400,
                scrollAreaWidth: 400,
                expected: nil,
                line: #line
            ),
            (
                scrollOffsetX: 800,
                scrollAreaWidth: 400,
                expected: nil,
                line: #line
            )
        ]
        
        for testCase in testCases {
            // Act
            let action = mediaViewerVM.pageControlBarInteractivePagingAction(
                on: .reloading,
                scrollOffsetX: testCase.scrollOffsetX,
                scrollAreaWidth: testCase.scrollAreaWidth
            )
            
            // Assert
            XCTAssertEqual(action, testCase.expected, line: testCase.line)
        }
    }
}
