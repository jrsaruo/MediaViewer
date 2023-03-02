//
//  ImageViewerOnePageView.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit

enum ImageTransition: Hashable, Sendable {
    case fade(duration: TimeInterval)
    case none
}

final class ImageViewerOnePageView: UIView {
    
    private enum LayoutState {
        case needsToLayout
        case laidOut
        case destroyedForTransition
    }
    
    let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 50
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
    
    private var layoutState: LayoutState = .needsToLayout
    private var constraintsBasedOnImageSize: [NSLayoutConstraint] = []
    private var didMakeAllLayoutConstraints = false
    
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
        backgroundColor = .black
        
        // Subviews
        scrollView.delegate = self
        scrollView.addSubview(imageView)
        addSubview(scrollView)
        
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
        invalidateLayout()
    }
    
    // MARK: - Methods
    
    /// Invalidates the current layout and triggers a layout update.
    func invalidateLayout() {
        NSLayoutConstraint.deactivate(constraintsBasedOnImageSize)
        configureLayoutBasedOnImageSize()
        layoutIfNeeded()
        adjustContentInset()
        layoutState = .laidOut
    }
    
    func setImage(_ image: UIImage?, with transition: ImageTransition) {
        switch transition {
        case .fade(let duration):
            UIView.transition(with: imageView,
                              duration: duration,
                              options: [.transitionCrossDissolve, .curveEaseInOut, .allowUserInteraction]) {
                self.setImage(image)
            }
        case .none:
            setImage(image)
        }
    }
    
    private func setImage(_ image: UIImage?) {
        imageView.image = image
        if didMakeAllLayoutConstraints {
            if layoutState == .destroyedForTransition {
                // Skip layout during the transition
                layoutState = .needsToLayout
            } else {
                invalidateLayout()
            }
        }
    }
    
    func updateZoomScaleOnDoubleTap(recognizedBy doubleTapRecognizer: UITapGestureRecognizer) {
        if scrollView.zoomScale == 1 {
            let location = doubleTapRecognizer.location(in: imageView)
            zoom(to: location, animated: true)
        } else {
            scrollView.setZoomScale(1, animated: true)
        }
    }
    
    private func zoom(to point: CGPoint, animated: Bool) {
        // Simulate the standard Photos app zoom
        let zoomArea: CGRect
        if scrollView.bounds.width < scrollView.bounds.height {
            let zoomAreaHeight: CGFloat
            if imageView.bounds.width > imageView.bounds.height {
                zoomAreaHeight = imageView.bounds.height
            } else {
                zoomAreaHeight = imageView.bounds.height * 2 / 3
            }
            zoomArea = CGRect(x: point.x,
                              y: point.y - zoomAreaHeight / 2,
                              width: 0,
                              height: zoomAreaHeight)
        } else {
            let zoomAreaWidth: CGFloat
            if imageView.bounds.width < imageView.bounds.height {
                zoomAreaWidth = imageView.bounds.width
            } else {
                zoomAreaWidth = imageView.bounds.width * 2 / 3
            }
            zoomArea = CGRect(x: point.x - zoomAreaWidth / 2,
                              y: point.y,
                              width: zoomAreaWidth,
                              height: 0)
        }
        scrollView.zoom(to: zoomArea, animated: animated)
    }
    
    func destroyLayoutConfigurationBeforeTransition() {
        NSLayoutConstraint.deactivate(constraintsBasedOnImageSize)
        removeConstraints(constraintsBasedOnImageSize)
        imageView.translatesAutoresizingMaskIntoConstraints = true
        imageView.removeFromSuperview()
        layoutState = .destroyedForTransition
    }
    
    func restoreLayoutConfigurationAfterTransition() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        configureLayoutBasedOnImageSize()
        if layoutState == .needsToLayout {
            layoutIfNeeded()
            adjustContentInset()
        }
        layoutState = .laidOut
    }
    
    private func configureLayoutBasedOnImageSize() {
        let imageSize = imageView.image?.size ?? bounds.size
        let imageWidthToHeight = imageSize.width / imageSize.height
        let viewWidthToHeight = bounds.width / bounds.height
        
        constraintsBasedOnImageSize = [
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
        constraintsBasedOnImageSize.append(contentsOf: scrollViewContentConstraints)
        
        NSLayoutConstraint.activate(constraintsBasedOnImageSize)
    }
    
    /// Adjusts the content inset of the scroll view.
    ///
    /// Center the image vertically when the image height is smaller than the scroll view.
    /// Removes the margin of the scrolling area when zooming makes the image higher than the scroll view.
    /// Adjust horizontally in the same way.
    private func adjustContentInset() {
        let verticalMargin = max((scrollView.bounds.height - imageView.frame.height) / 2, 0)
        let horizontalMargin = max((scrollView.bounds.width - imageView.frame.width) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: verticalMargin,
                                               left: horizontalMargin,
                                               bottom: verticalMargin,
                                               right: horizontalMargin)
    }
}

extension ImageViewerOnePageView: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        adjustContentInset()
    }
}
