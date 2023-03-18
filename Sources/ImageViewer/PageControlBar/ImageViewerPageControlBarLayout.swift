//
//  ImageViewerPageControlBarLayout.swift
//  
//
//  Created by Yusaku Nishi on 2023/03/18.
//

import UIKit

final class ImageViewerPageControlBarLayout: UICollectionViewLayout {
    
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
        
        let compactItemWidth: CGFloat = 21
        let compactItemSpacing: CGFloat = 1
        
        let contentWidth = (compactItemWidth + compactItemSpacing) * CGFloat(numberOfItems) - compactItemSpacing
        contentSize = CGSize(width: contentWidth,
                             height: collectionView.bounds.height)
        
        for item in 0 ..< numberOfItems {
            let indexPath = IndexPath(item: item, section: 0)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = CGRect(x: (compactItemWidth + compactItemSpacing) * CGFloat(item),
                                      y: 0,
                                      width: compactItemWidth,
                                      height: collectionView.bounds.height)
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
