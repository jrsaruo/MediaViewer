//
//  PhotoCell.swift
//  ImageViewerDemo
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit
import AceLayout
import Photos

final class PhotoCell: UICollectionViewCell {
    
    let imageView = UIImageView()
    
    private var imageRequestID: PHImageRequestID?
    
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
    
    // MARK: - Lifecycle
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        if let imageRequestID {
            PHImageManager.default().cancelImageRequest(imageRequestID)
        }
        imageRequestID = nil
        imageView.image = nil
    }
    
    // MARK: - Methods
    
    func configure(with asset: PHAsset, contentMode: UIView.ContentMode) {
        imageView.contentMode = contentMode
        imageRequestID = PHImageManager.default()
            .requestImage(for: asset,
                          targetSize: .init(width: bounds.size.width * 3,
                                            height: bounds.size.height * 3),
                          contentMode: contentMode == .scaleAspectFit ? .aspectFit : .aspectFill,
                          options: nil) { [weak self] image, info in
                if let info, let isCancelled = info[PHImageCancelledKey] as? Bool, isCancelled {
                    return
                }
                self?.imageView.image = image
            }
    }
}
