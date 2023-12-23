//
//  ImageGridView.swift
//  MediaViewerDemo
//
//  Created by Yusaku Nishi on 2023/03/05.
//

import UIKit
import AceLayout

final class ImageGridView: UIView {
    
    let collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, layoutEnvironment in
            let minimumItemWidth: CGFloat
            let itemSpacing: CGFloat
            let contentInsetsReference: UIContentInsetsReference
            switch layoutEnvironment.traitCollection.horizontalSizeClass {
            case .unspecified, .compact:
                minimumItemWidth = 130
                itemSpacing = 2
                contentInsetsReference = .automatic
            case .regular:
                minimumItemWidth = 160
                itemSpacing = 16
                contentInsetsReference = .layoutMargins
            @unknown default:
                fatalError()
            }
            
            let effectiveFullWidth = layoutEnvironment.container.effectiveContentSize.width
            let columnCount = Int(effectiveFullWidth / minimumItemWidth)
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
            section.contentInsetsReference = contentInsetsReference
            return section
        }
        
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        collectionView.preservesSuperviewLayoutMargins = true
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
        preservesSuperviewLayoutMargins = true
        backgroundColor = .systemBackground
        
        // Subviews
        addSubview(collectionView)
        
        // Layout
        collectionView.autoLayout { item in
            item.edges.equalToSuperview()
        }
    }
}
