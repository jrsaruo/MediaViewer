//
//  PageControlBarThumbnailCell.swift
//  
//
//  Created by Yusaku Nishi on 2023/03/19.
//

import UIKit

final class PageControlBarThumbnailCell: UICollectionViewCell {
    
    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()
    
    private var imageLoadingTask: Task<(), Never>?
    
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
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    // MARK: Lifecycle
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Reset changes by delete animation.
        transform = .identity
        alpha = 1
        
        imageLoadingTask?.cancel()
        imageLoadingTask = nil
        imageView.image = nil
    }
    
    // MARK: - Methods
    
    func configure(with imageSource: Source<UIImage?>) {
        imageLoadingTask = imageView.load(imageSource)
    }
    
    func performVanishAnimationBody() {
        // TODO: Apply the same blur effect as standard
        // NOTE: These changes are reset in prepareForReuse().
        transform = transform.scaledBy(x: 0.5, y: 0.5)
        alpha = 0
    }
}
