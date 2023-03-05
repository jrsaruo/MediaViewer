//
//  ImageGridView.swift
//  ImageViewerDemo
//
//  Created by Yusaku Nishi on 2023/03/05.
//

import UIKit
import AceLayout

final class ImageGridView: UIView {
    
    let collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, layoutEnvironment in
            let columnCount = 3
            let itemSpacing: CGFloat = 2
            
            let effectiveFullWidth = layoutEnvironment.container.effectiveContentSize.width
            let totalSpacing = itemSpacing * CGFloat(columnCount - 1)
            let estimatedItemWidth = (effectiveFullWidth - totalSpacing) / CGFloat(columnCount)
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(estimatedItemWidth)
                ),
                repeatingSubitem: .init(layoutSize: .init(
                    widthDimension: .fractionalWidth(1 / CGFloat(columnCount)),
                    heightDimension: .estimated(estimatedItemWidth)
                )),
                count: columnCount
            )
            group.interItemSpacing = .fixed(itemSpacing)
            
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = itemSpacing
            return section
        }
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(PhotoCell.self)
        return collectionView
    }()
    
    // MARK: - Initializers
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpViews()
    }
    
    private func setUpViews() {
        // Subviews
        addSubview(collectionView)
        
        // Layout
        collectionView.autoLayout { item in
            item.edges.equalToSuperview()
        }
    }
}
