//
//  ImageViewerPageControlBarLayout.swift
//  
//
//  Created by Yusaku Nishi on 2023/03/18.
//

import UIKit

final class ImageViewerPageControlBarLayout: UICollectionViewLayout {
    
    var indexPathForExpandingItem: IndexPath?
    
    let compactItemWidth: CGFloat = 21
    
    private var attributesDictionary: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var contentSize: CGSize = .zero
    
    // MARK: - Override
    
    override var collectionViewContentSize: CGSize {
        contentSize
    }
    
    override func prepare() {
        // Reset
        attributesDictionary.removeAll(keepingCapacity: true)
        contentSize = .zero
        
        guard let collectionView, collectionView.numberOfSections == 1 else { return }
        let numberOfItems = collectionView.numberOfItems(inSection: 0)
        guard numberOfItems > 0 else { return }
        
        let expandingImageWidthToHeight: CGFloat = 1.8 // TODO: Use the correct ratio
        
        let expandedItemWidth: CGFloat = collectionView.bounds.height * expandingImageWidthToHeight
        let compactItemSpacing: CGFloat = 1
        let expandedItemSpacing: CGFloat = 12
        
        // Calculate frames for each item
        var frames: [IndexPath: CGRect] = [:]
        for item in 0 ..< numberOfItems {
            let indexPath = IndexPath(item: item, section: 0)
            let previousIndexPath = IndexPath(item: item - 1, section: 0)
            let width: CGFloat
            let itemSpacing: CGFloat
            switch indexPathForExpandingItem {
            case indexPath:
                width = expandedItemWidth
                itemSpacing = expandedItemSpacing
            case previousIndexPath:
                width = compactItemWidth
                itemSpacing = expandedItemSpacing
            default:
                width = compactItemWidth
                itemSpacing = compactItemSpacing
            }
            let previousFrame = frames[previousIndexPath]
            let x = previousFrame.map { $0.maxX + itemSpacing } ?? 0
            frames[indexPath] = CGRect(x: x,
                                       y: 0,
                                       width: width,
                                       height: collectionView.bounds.height)
        }
        
        // Calculate the content size
        let lastItemFrame = frames[IndexPath(item: numberOfItems - 1, section: 0)]!
        contentSize = CGSize(width: lastItemFrame.maxX,
                             height: collectionView.bounds.height)
        
        // Set up layout attributes
        for (indexPath, frame) in frames {
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = frame
            attributesDictionary[indexPath] = attributes
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        attributesDictionary.values.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        attributesDictionary[indexPath]
    }
}
