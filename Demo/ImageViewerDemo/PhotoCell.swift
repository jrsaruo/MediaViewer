//
//  PhotoCell.swift
//  ImageViewerDemo
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit
import AceLayout

final class PhotoCell: UICollectionViewCell {
    
    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .secondarySystemBackground
        return imageView
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
        clipsToBounds = true
        
        // Subviews
        contentView.addSubview(imageView)
        
        // Layout
        imageView.autoLayout { item in
            item.edges.equalToSuperview()
            item.width.equal(to: item.height)
        }
    }
}
