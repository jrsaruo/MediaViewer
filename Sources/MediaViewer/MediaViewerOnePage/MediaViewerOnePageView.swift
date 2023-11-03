//
//  MediaViewerOnePageView.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit

final class MediaViewerOnePageView: UIView {
    
    private enum LayoutState {
        
        /// The layout has not yet been run.
        ///
        /// It can only be in this state until the first `layoutSubviews()` runs.
        case notYet
        
        case laidOut
        case destroyedForTransition
    }
    
    let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.decelerationRate = .fast
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 50
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
    
    private var layoutState: LayoutState = .notYet
    private var constraintsBasedOnImageSize: [NSLayoutConstraint] = []
    
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
        
        switch layoutState {
        case .notYet:
            invalidateLayout()
        case .laidOut, .destroyedForTransition:
            break
        }
    }
    
    // MARK: - Methods
    
    /// Invalidates the current layout and triggers a layout update.
    func invalidateLayout() {
        NSLayoutConstraint.deactivate(constraintsBasedOnImageSize)
        layOutBasedOnImageSize()
    }
    
    func setImage(_ image: UIImage?, with transition: ImageTransition) {
        switch transition {
        case .fade(let duration):
            UIView.transition(
                with: imageView,
                duration: duration,
                options: [.transitionCrossDissolve, .curveEaseInOut, .allowUserInteraction]
            ) {
                self.setImage(image)
            }
        case .none:
            setImage(image)
        }
    }
    
    private func setImage(_ image: UIImage?) {
        imageView.image = image
        switch layoutState {
        case .notYet:
            break // Skip layout because layoutSubviews will run layout.
        case .laidOut:
            invalidateLayout()
        case .destroyedForTransition:
            break // Skip layout during the transition.
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
            zoomArea = CGRect(
                x: point.x,
                y: point.y - zoomAreaHeight / 2,
                width: 0,
                height: zoomAreaHeight
            )
        } else {
            let zoomAreaWidth: CGFloat
            if imageView.bounds.width < imageView.bounds.height {
                zoomAreaWidth = imageView.bounds.width
            } else {
                zoomAreaWidth = imageView.bounds.width * 2 / 3
            }
            zoomArea = CGRect(
                x: point.x - zoomAreaWidth / 2,
                y: point.y,
                width: zoomAreaWidth,
                height: 0
            )
        }
        scrollView.zoom(to: zoomArea, animated: animated)
    }
    
    func destroyLayoutConfigurationBeforeTransition() {
        NSLayoutConstraint.deactivate(constraintsBasedOnImageSize)
        imageView.translatesAutoresizingMaskIntoConstraints = true
        imageView.removeFromSuperview()
        layoutState = .destroyedForTransition
    }
    
    func restoreLayoutConfigurationAfterTransition() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        layOutBasedOnImageSize()
    }
    
    /// Lays out subviews based on the image size.
    private func layOutBasedOnImageSize() {
        let imageSize = imageView.image?.size ?? bounds.size
        let imageWidthToHeight = imageSize.width / imageSize.height
        let viewWidthToHeight = bounds.width / bounds.height
        
        assert(constraintsBasedOnImageSize.allSatisfy { !$0.isActive })
        constraintsBasedOnImageSize = [
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(
                equalTo: imageView.heightAnchor,
                multiplier: imageWidthToHeight
            )
        ]
        
        let scrollViewContentConstraint: NSLayoutConstraint
        if imageWidthToHeight > viewWidthToHeight {
            scrollViewContentConstraint = scrollView.contentLayoutGuide.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor
            )
        } else {
            scrollViewContentConstraint = scrollView.contentLayoutGuide.heightAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.heightAnchor
            )
        }
        constraintsBasedOnImageSize.append(scrollViewContentConstraint)
        
        NSLayoutConstraint.activate(constraintsBasedOnImageSize)
        
        layoutIfNeeded()
        adjustContentInset()
        
        layoutState = .laidOut
    }
    
    /// Adjusts the content inset of the scroll view.
    ///
    /// Center the image vertically when the image height is smaller than the scroll view.
    /// Removes the margin of the scrolling area when zooming makes the image higher than the scroll view.
    /// Adjust horizontally in the same way.
    private func adjustContentInset() {
        let verticalMargin = max((scrollView.bounds.height - imageView.frame.height) / 2, 0)
        let horizontalMargin = max((scrollView.bounds.width - imageView.frame.width) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(
            top: verticalMargin,
            left: horizontalMargin,
            bottom: verticalMargin,
            right: horizontalMargin
        )
    }
}

extension MediaViewerOnePageView: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        adjustContentInset()
    }
}
