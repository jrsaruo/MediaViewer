//
//  ImageViewerView.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit

final class ImageViewerView: UIView {
    
    let singleTapRecognizer = UITapGestureRecognizer()
    let panRecognizer = UIPanGestureRecognizer()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        return scrollView
    }()
    
    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.isUserInteractionEnabled = true
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private var constraintsToBeDeactivatedDuringTransition: [NSLayoutConstraint] = []
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
        addGestureRecognizer(panRecognizer)
        
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
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    // MARK: - Lifecycle
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setUpLayoutIfNotYet()
    }
    
    /// Configure the scrolling content layout and the image view aspect ratio if not yet.
    private func setUpLayoutIfNotYet() {
        guard !didMakeAllLayoutConstraints else { return }
        didMakeAllLayoutConstraints = true
        configureLayoutBasedOnImageSize()
        
        layoutIfNeeded()
        adjustContentInset()
    }
    
    // MARK: - Methods
    
    func destroyConfigurationsBeforeTransition() {
        NSLayoutConstraint.deactivate(constraintsToBeDeactivatedDuringTransition)
        removeConstraints(constraintsToBeDeactivatedDuringTransition)
        imageView.translatesAutoresizingMaskIntoConstraints = true
        imageView.removeFromSuperview()
    }
    
    private func configureLayoutBasedOnImageSize() {
        let imageSize = imageView.image?.size ?? bounds.size
        let imageWidthToHeight = imageSize.width / imageSize.height
        let viewWidthToHeight = bounds.width / bounds.height
        
        constraintsToBeDeactivatedDuringTransition = [
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: imageWidthToHeight)
        ]
        
        let scrollViewContentConstraints: [NSLayoutConstraint]
        if imageWidthToHeight > viewWidthToHeight {
            scrollViewContentConstraints = [
                scrollView.contentLayoutGuide.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
                scrollView.contentLayoutGuide.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor)
            ]
        } else {
            scrollViewContentConstraints = [
                scrollView.contentLayoutGuide.topAnchor.constraint(equalTo: scrollView.frameLayoutGuide.topAnchor),
                scrollView.contentLayoutGuide.bottomAnchor.constraint(equalTo: scrollView.frameLayoutGuide.bottomAnchor)
            ]
        }
        constraintsToBeDeactivatedDuringTransition.append(contentsOf: scrollViewContentConstraints)
        
        NSLayoutConstraint.activate(constraintsToBeDeactivatedDuringTransition)
    }
    
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
