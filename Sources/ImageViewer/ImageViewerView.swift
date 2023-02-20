//
//  ImageViewerView.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit

final class ImageViewerView: UIView {
    
    private(set) lazy var singleTapRecognizer = UITapGestureRecognizer()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        return scrollView
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.isUserInteractionEnabled = true
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private var didMakeAllLayoutConstraints = false
    
    // MARK: - Initializers
    
    init(image: UIImage) {
        super.init(frame: .null)
        
        setUpViews()
        imageView.image = image
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpViews()
    }
    
    private func setUpViews() {
        backgroundColor = .black
        addGestureRecognizer(singleTapRecognizer)
        
        // Subviews
        scrollView.delegate = self
        addSubview(scrollView)
        
        let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageDoubleTapped))
        doubleTapRecognizer.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTapRecognizer)
        scrollView.addSubview(imageView)
        
        singleTapRecognizer.require(toFail: doubleTapRecognizer)
        
        // Layout
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
        ])
    }
    
    // MARK: - Lifecycle
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setUpLayoutIfNotYet()
    }
    
    /// Configure the scrolling content layout and the image view aspect ratio if not yet.
    private func setUpLayoutIfNotYet() {
        guard let image = imageView.image, !didMakeAllLayoutConstraints else { return }
        didMakeAllLayoutConstraints = true
        
        let imageWidthToHeight = image.size.width / image.size.height
        let viewWidthToHeight = bounds.width / bounds.height
        
        let imageViewConstraints: [NSLayoutConstraint]
        let imageViewAspectRatioConstraint = imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor,
                                                                              multiplier: imageWidthToHeight)
        if imageWidthToHeight > viewWidthToHeight {
            imageViewConstraints = [
                scrollView.contentLayoutGuide.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
                scrollView.contentLayoutGuide.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
                imageViewAspectRatioConstraint
            ]
        } else {
            imageViewConstraints = [
                scrollView.contentLayoutGuide.topAnchor.constraint(equalTo: scrollView.frameLayoutGuide.topAnchor),
                scrollView.contentLayoutGuide.bottomAnchor.constraint(equalTo: scrollView.frameLayoutGuide.bottomAnchor),
                imageViewAspectRatioConstraint
            ]
        }
        NSLayoutConstraint.activate(imageViewConstraints)
        
        layoutIfNeeded()
        adjustContentInset()
    }
    
    // MARK: - Methods
    
    /// Adjusts the content inset of the scroll view.
    ///
    /// Center the image vertically when the image height is smaller than the scroll view.
    /// Removes the margin of the scrolling area when zooming makes the image higher than the scroll view.
    /// Adjust horizontally in the same way.
    private func adjustContentInset() {
        let verticalMargin = max((scrollView.bounds.height - imageView.frame.height) / 2, 0)
        let horizontalMargin = max((scrollView.bounds.width - imageView.frame.width) / 2, 0)
        print(verticalMargin)
        scrollView.contentInset = UIEdgeInsets(top: verticalMargin,
                                               left: horizontalMargin,
                                               bottom: verticalMargin,
                                               right: horizontalMargin)
    }
    
    // MARK: - Actions
    
    @objc
    private func imageDoubleTapped(recognizer: UITapGestureRecognizer) {
        if scrollView.zoomScale == 1 {
            let location = recognizer.location(in: imageView)
            scrollView.zoom(to: CGRect(origin: location, size: .zero), animated: true)
        } else {
            scrollView.setZoomScale(1, animated: true)
        }
    }
}

extension ImageViewerView: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        adjustContentInset()
    }
}
