//
//  ImageViewerPageControlBarLayout.swift
//  
//
//  Created by Yusaku Nishi on 2023/03/18.
//

import UIKit

final class ImageViewerPageControlBarLayout: UICollectionViewLayout {
    
    enum Style {
        case expanded(IndexPath, referenceSizeForAspectRatio: CGSize?)
        case collapsed
        
        var indexPathForExpandingItem: IndexPath? {
            switch self {
            case .expanded(let indexPath, _):
                return indexPath
            case .collapsed:
                return nil
            }
        }
    }
    
    let style: Style
    
    var expandedItemWidth: CGFloat?
    let collapsedItemWidth: CGFloat = 21
    
    private var attributesDictionary: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var contentSize: CGSize = .zero
    
    // MARK: - Initializers
    
    init(style: Style) {
        self.style = style
        super.init()
    }
    
    required init?(coder: NSCoder) {
        self.style = .collapsed
        super.init(coder: coder)
    }
    
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
        
        // NOTE: Cache and reuse expandedItemWidth for smooth animation.
        let expandedItemWidth = self.expandedItemWidth ?? expandingItemWidth(in: collectionView)
        self.expandedItemWidth = expandedItemWidth
        
        let collapsedItemSpacing: CGFloat = 1
        let expandedItemSpacing: CGFloat = 12
        
        // Calculate frames for each item
        var frames: [IndexPath: CGRect] = [:]
        for item in 0 ..< numberOfItems {
            let indexPath = IndexPath(item: item, section: 0)
            let previousIndexPath = IndexPath(item: item - 1, section: 0)
            let width: CGFloat
            let itemSpacing: CGFloat
            switch style.indexPathForExpandingItem {
            case indexPath:
                width = expandedItemWidth
                itemSpacing = expandedItemSpacing
            case previousIndexPath:
                width = collapsedItemWidth
                itemSpacing = expandedItemSpacing
            default:
                width = collapsedItemWidth
                itemSpacing = collapsedItemSpacing
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
    
    private func expandingItemWidth(in collectionView: UICollectionView) -> CGFloat {
        // Determine the expanding item size
        let expandingImageSize: CGSize
        switch style {
        case .expanded(let indexPath, let referenceSize):
            if let referenceSize {
                expandingImageSize = referenceSize
            } else if let cell = collectionView.cellForItem(at: indexPath) {
                let cell = cell as! PageControlBarThumbnailCell
                let image = cell.imageView.image
                expandingImageSize = image?.size ?? .zero
            } else {
                expandingImageSize = .zero
            }
        case .collapsed:
            expandingImageSize = .zero
        }
        
        // Calculate the expanding item width
        let expandingImageWidthToHeight: CGFloat
        if expandingImageSize.height > 0 {
            expandingImageWidthToHeight = expandingImageSize.width / expandingImageSize.height
        } else {
            expandingImageWidthToHeight = 0
        }
        return max(
            collectionView.bounds.height * expandingImageWidthToHeight,
            collapsedItemWidth
        )
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        attributesDictionary.values.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        attributesDictionary[indexPath]
    }
}
