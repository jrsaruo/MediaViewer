//
//  MediaViewerPageControlBarLayout.swift
//
//
//  Created by Yusaku Nishi on 2023/03/18.
//

import UIKit

final class MediaViewerPageControlBarLayout: UICollectionViewLayout {
    
    enum Style {
        case expanded(IndexPath, expandingThumbnailWidthToHeight: CGFloat?)
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
    
    private var cachedExpandedItemWidth: CGFloat?
    
    static var collapsedItemWidth: CGFloat {
        if #available(iOS 26, *) { 20 } else { 21 }
    }
    
    private var attributesDictionary: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var contentSize: CGSize = .zero
    
    private var isLayoutCacheInvalidated = true
    
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
    
    private var previousBounds: CGRect = .zero
    
    override func shouldInvalidateLayout(
        forBoundsChange newBounds: CGRect
    ) -> Bool {
        defer {
            previousBounds = newBounds
        }
        if previousBounds.height != newBounds.height {
            /*
             NOTE:
             Cells' height depend on the bounds height
             so they should be updated when the bounds height is changed.
             */
            isLayoutCacheInvalidated = true
            cachedExpandedItemWidth = nil
            return true
        }
        return super.shouldInvalidateLayout(forBoundsChange: newBounds)
    }
    
    override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        if context.invalidateEverything || context.invalidateDataSourceCounts {
            isLayoutCacheInvalidated = true
        }
        super.invalidateLayout(with: context)
    }
    
    override func prepare() {
        guard isLayoutCacheInvalidated else { return }
        
        // Reset
        attributesDictionary.removeAll(keepingCapacity: true)
        contentSize = .zero
        
        guard let collectionView, collectionView.numberOfSections == 1 else { return }
        let numberOfItems = collectionView.numberOfItems(inSection: 0)
        guard numberOfItems > 0 else { return }
        
        defer {
            isLayoutCacheInvalidated = false
        }
        
        // NOTE: Cache and reuse expandedItemWidth for smooth animation.
        let expandedItemWidth = cachedExpandedItemWidth ?? expandingItemWidth(in: collectionView)
        self.cachedExpandedItemWidth = expandedItemWidth
        
        let collapsedItemSpacing: CGFloat
        let expandedItemSpacing: CGFloat
        if #available(iOS 26, *) {
            collapsedItemSpacing = 3
            expandedItemSpacing = 13
        } else {
            collapsedItemSpacing = 1
            expandedItemSpacing = 12
        }
        
        // NOTE: Calculate width and item-spacing in advance for performance.
        var _widthAndSpacings: [IndexPath: (width: CGFloat, itemSpacing: CGFloat)] = [:]
        switch style {
        case .expanded(let indexPath, _):
            _widthAndSpacings[indexPath] = (
                width: expandedItemWidth,
                itemSpacing: expandedItemSpacing
            )
            var nextIndexPath = indexPath
            nextIndexPath.item += 1
            _widthAndSpacings[nextIndexPath] = (
                width: Self.collapsedItemWidth,
                itemSpacing: expandedItemSpacing
            )
        case .collapsed:
            break
        }
        
        func widthAndSpacings(
            for indexPath: IndexPath
        ) -> (width: CGFloat, itemSpacing: CGFloat) {
            _widthAndSpacings[
                indexPath,
                default: (
                    width: Self.collapsedItemWidth,
                    itemSpacing: collapsedItemSpacing
                )
            ]
        }
        
        attributesDictionary.reserveCapacity(numberOfItems)
        
        let firstIndexPath = IndexPath(item: 0, section: 0)
        // NOTE: Initial previousMaxX + initial itemSpacing should be 0.
        var previousMaxX = -widthAndSpacings(for: firstIndexPath).itemSpacing
        
        // Calculate frames for each item
        for item in 0..<numberOfItems {
            let indexPath = IndexPath(item: item, section: 0)
            let (width, itemSpacing) = widthAndSpacings(for: indexPath)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = CGRect(
                x: previousMaxX + itemSpacing,
                y: 0,
                width: width,
                height: collectionView.bounds.height
            )
            attributesDictionary[indexPath] = attributes
            previousMaxX = attributes.frame.maxX
        }
        assert(attributesDictionary[firstIndexPath]?.frame.minX == 0)
        
        // Calculate the content size
        let lastItemMaxX = previousMaxX
        contentSize = CGSize(
            width: lastItemMaxX,
            height: collectionView.bounds.height
        )
    }
    
    private func expandingItemWidth(in collectionView: UICollectionView) -> CGFloat {
        let expandingThumbnailWidthToHeight: CGFloat
        switch style {
        case .expanded(let indexPath, let thumbnailWidthToHeight):
            if let thumbnailWidthToHeight {
                expandingThumbnailWidthToHeight = thumbnailWidthToHeight
            } else if let cell = collectionView.cellForItem(at: indexPath) {
                let cell = cell as! PageControlBarThumbnailCell
                let image = cell.imageView.image
                if let imageSize = image?.size, imageSize.height > 0 {
                    expandingThumbnailWidthToHeight = imageSize.width / imageSize.height
                } else {
                    expandingThumbnailWidthToHeight = 0
                }
            } else {
                expandingThumbnailWidthToHeight = 0
            }
        case .collapsed:
            expandingThumbnailWidthToHeight = 0
        }
        
        let minimumWidth = Self.collapsedItemWidth
        let maximumWidth = 84.0
        return min(
            max(
                collectionView.bounds.height * expandingThumbnailWidthToHeight,
                minimumWidth
            ),
            maximumWidth
        )
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        attributesDictionary.values.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        attributesDictionary[indexPath]
    }
    
    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint
    ) -> CGPoint {
        let offset = super.targetContentOffset(
            forProposedContentOffset: proposedContentOffset
        )
        guard let collectionView else { return offset }
        
        // Center the target item.
        let indexPathForCenterItem: IndexPath
        switch style {
        case .expanded(let indexPathForExpandingItem, _):
            indexPathForCenterItem = indexPathForExpandingItem
        case .collapsed:
            guard let indexPath = collectionView.indexPathForHorizontalCenterItem else {
                return offset
            }
            indexPathForCenterItem = indexPath
        }
        
        guard let centerItemAttributes = layoutAttributesForItem(at: indexPathForCenterItem) else {
            return offset
        }
        return CGPoint(
            x: centerItemAttributes.center.x - collectionView.bounds.width / 2,
            y: offset.y
        )
    }
}
