//
//  ImageViewerPageControlBar.swift
//  
//
//  Created by Yusaku Nishi on 2023/03/18.
//

import UIKit

protocol ImageViewerPageControlBarDelegate: AnyObject {
    func imageViewerPageControlBar(_ pageControlBar: ImageViewerPageControlBar,
                                   didVisitThumbnailOnPage page: Int)
}

final class ImageViewerPageControlBar: UIView {
    
    weak var delegate: (any ImageViewerPageControlBarDelegate)?
    
    private let layout = ImageViewerPageControlBarLayout()
    
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.showsHorizontalScrollIndicator = false
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
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    // MARK: - Override
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: super.intrinsicContentSize.width,
               height: 42)
    }
}
