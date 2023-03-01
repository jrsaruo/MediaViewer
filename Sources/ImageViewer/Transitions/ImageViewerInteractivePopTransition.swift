//
//  ImageViewerInteractivePopTransition.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/23.
//

import UIKit

final class ImageViewerInteractivePopTransition: NSObject {
    
    private let sourceThumbnailView: UIImageView
    
    private var animator: UIViewPropertyAnimator?
    private var transitionContext: (any UIViewControllerContextTransitioning)?
    
    // MARK: Backups
    
    private var thumbnailHiddenBackup = false
    private var initialZoomScale: CGFloat = 1
    private var initialImageTransform = CGAffineTransform.identity
    private var initialImageFrameInContainer = CGRect.null
    
    // MARK: - Initializers
    
    init(sourceThumbnailView: UIImageView) {
        self.sourceThumbnailView = sourceThumbnailView
        super.init()
    }
}

extension ImageViewerInteractivePopTransition: UIViewControllerInteractiveTransitioning {
    
    func startInteractiveTransition(_ transitionContext: any UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to) else {
            preconditionFailure("\(Self.self) works only with the pop animation for \(ImageViewerViewController.self).")
        }
        self.transitionContext = transitionContext
        let containerView = transitionContext.containerView
        let currentPageView = imageViewerCurrentPageView(in: transitionContext)
        let currentPageImageView = currentPageView.imageView
        
        // Back up
        thumbnailHiddenBackup = sourceThumbnailView.isHidden
        initialZoomScale = currentPageView.zoomScale
        initialImageTransform = currentPageImageView.transform
        initialImageFrameInContainer = containerView.convert(currentPageImageView.frame,
                                                             from: currentPageImageView.superview)
        
        // Prepare for transition
        currentPageView.destroyLayoutConfigurationBeforeTransition()
        currentPageImageView.frame = initialImageFrameInContainer
        
        containerView.addSubview(toView)
        containerView.addSubview(fromView)
        containerView.addSubview(currentPageImageView)
        
        sourceThumbnailView.isHidden = true
        
        // Animation
        animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1) {
            fromView.alpha = 0
        }
    }
    
    private func finishInteractiveTransition() {
        guard let animator, let transitionContext else { return }
        transitionContext.finishInteractiveTransition()
        
        let duration = 0.35
        animator.continueAnimation(withTimingParameters: nil, durationFactor: duration)
        
        let containerView = transitionContext.containerView
        let currentPageView = imageViewerCurrentPageView(in: transitionContext)
        let currentPageImageView = currentPageView.imageView
        
        let finishAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
            let thumbnailFrameInContainer = containerView.convert(self.sourceThumbnailView.frame,
                                                                  from: self.sourceThumbnailView)
            currentPageImageView.frame = thumbnailFrameInContainer
            currentPageImageView.transitioningConfiguration = self.sourceThumbnailView.transitioningConfiguration
            currentPageImageView.layer.masksToBounds = true // TODO: Change according to the thumbnail configuration
        }
        finishAnimator.addCompletion { _ in
            self.sourceThumbnailView.isHidden = self.thumbnailHiddenBackup
            currentPageView.removeFromSuperview()
            currentPageImageView.removeFromSuperview()
            transitionContext.completeTransition(true)
        }
        finishAnimator.startAnimation()
    }
    
    private func cancelInteractiveTransition() {
        guard let animator, let transitionContext else { return }
        transitionContext.cancelInteractiveTransition()
        
        let duration = 0.3
        animator.isReversed = true
        animator.continueAnimation(withTimingParameters: nil, durationFactor: duration)
        
        let currentPageView = imageViewerCurrentPageView(in: transitionContext)
        let currentPageImageView = currentPageView.imageView
        
        let cancelAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
            currentPageImageView.frame = self.initialImageFrameInContainer
        }
        cancelAnimator.addCompletion { _ in
            // Restore to pre-transition state
            self.sourceThumbnailView.isHidden = self.thumbnailHiddenBackup
            currentPageImageView.updateAnchorPointWithoutMoving(.init(x: 0.5, y: 0.5))
            currentPageImageView.transform = self.initialImageTransform
            currentPageView.restoreLayoutConfigurationAfterTransition()
            
            transitionContext.completeTransition(false)
        }
        cancelAnimator.startAnimation()
    }
    
    private func imageViewerCurrentPageView(in transitionContext: any UIViewControllerContextTransitioning) -> ImageViewerOnePageView {
        guard let imageViewer = transitionContext.viewController(forKey: .from) as? ImageViewerViewController else {
            preconditionFailure("\(Self.self) works only with the pop animation for \(ImageViewerViewController.self).")
        }
        return imageViewer.currentPageViewController.imageViewerOnePageView
    }
    
    func panRecognized(by recognizer: UIPanGestureRecognizer,
                       in imageViewer: ImageViewerViewController) {
        let currentPageView = imageViewer.currentPageViewController.imageViewerOnePageView
        let panningImageView = currentPageView.imageView
        
        switch recognizer.state {
        case .possible, .began:
            // Adjust the anchor point to scale the image around a finger
            let location = recognizer.location(in: panningImageView.superview)
            let anchorPoint = CGPoint(x: location.x / panningImageView.frame.width,
                                      y: location.y / panningImageView.frame.height)
            panningImageView.updateAnchorPointWithoutMoving(anchorPoint)
        case .changed:
            guard let animator, let transitionContext else {
                // NOTE: Sometimes this method is called before startInteractiveTransition(_:) and enters here.
                return
            }
            let translation = recognizer.translation(in: currentPageView)
            let panAreaSize = currentPageView.bounds.size
            
            let transitionProgress = translation.y * 2 / panAreaSize.height
            animator.fractionComplete = transitionProgress
            transitionContext.updateInteractiveTransition(transitionProgress)
            
            panningImageView.transform = panningImageTransform(translation: translation,
                                                               panAreaSize: panAreaSize)
        case .ended:
            let isMovingDown = recognizer.velocity(in: nil).y > 0
            if isMovingDown {
                finishInteractiveTransition()
            } else {
                cancelInteractiveTransition()
            }
        case .cancelled, .failed:
            cancelInteractiveTransition()
        @unknown default:
            assertionFailure()
            cancelInteractiveTransition()
        }
    }
    
    /// Calculate an affine transformation matrix for the panning image.
    ///
    /// Ease translation and image scale changes.
    ///
    /// - Parameters:
    ///   - translation: The total translation over time.
    ///   - panAreaSize: The size of the panning area.
    /// - Returns: An affine transformation matrix for the panning image.
    private func panningImageTransform(translation: CGPoint,
                                       panAreaSize: CGSize) -> CGAffineTransform {
        // Translation x: ease-in-out from the left to the right
        let maxX = panAreaSize.width * 0.4
        let translationX = sin(translation.x / panAreaSize.width * .pi / 2) * maxX
        
        let translationY: CGFloat
        let imageScale: CGFloat
        if translation.y >= 0 {
            // Translation y: linear during pull-down
            translationY = translation.y
            
            // Image scale: ease-out during pull-down
            let maxScale = 1.0
            let minScale = 0.6
            let difference = maxScale - minScale
            imageScale = maxScale - sin(translation.y * .pi / 2 / panAreaSize.height) * difference
        } else {
            // Translation y: ease-out during pull-up
            let minY = -panAreaSize.height / 3.8
            translationY = easeOutQuadratic(-translation.y / panAreaSize.height) * minY
            
            // Image scale: not change during pull-up
            imageScale = 1
        }
        return initialImageTransform
            .translatedBy(x: translationX / initialZoomScale,
                          y: translationY / initialZoomScale)
            .scaledBy(x: imageScale, y: imageScale)
    }
    
    private func easeOutQuadratic(_ x: Double) -> Double {
        -x * (x - 2)
    }
}
