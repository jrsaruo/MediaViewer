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
    private var currentPageImageFrameInContainerBackup = CGRect.null
    
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
        currentPageImageFrameInContainerBackup = containerView.convert(currentPageImageView.frame,
                                                                       from: currentPageImageView)
        
        // Prepare for transition
        currentPageView.destroyLayoutConfigurationBeforeTransition()
        currentPageImageView.frame = currentPageImageFrameInContainerBackup
        
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
            currentPageImageView.frame = self.currentPageImageFrameInContainerBackup
        }
        cancelAnimator.addCompletion { _ in
            // Restore to pre-transition state
            self.sourceThumbnailView.isHidden = self.thumbnailHiddenBackup
            currentPageImageView.updateAnchorPointWithoutMoving(.init(x: 0.5, y: 0.5))
            currentPageImageView.transform = .identity
            currentPageView.restoreLayoutConfigurationAfterTransition()
            
            transitionContext.completeTransition(false)
        }
        cancelAnimator.startAnimation()
    }
    
    private func imageViewerCurrentPageView(in transitionContext: any UIViewControllerContextTransitioning) -> ImageViewerOnePageView {
        guard let imageViewer = transitionContext.viewController(forKey: .from) as? ImageViewerViewController else {
            preconditionFailure("\(Self.self) works only with the pop animation for ImageViewerViewController.")
        }
        return imageViewer.currentPageViewController.imageViewerOnePageView
    }
    
    func panRecognized(by recognizer: UIPanGestureRecognizer) {
        guard let animator, let transitionContext else {
            // NOTE: Sometimes this method is called before startInteractiveTransition(_:) and enters here.
            return
        }
        let currentPageView = imageViewerCurrentPageView(in: transitionContext)
        let panningImageView = currentPageView.imageView
        
        switch recognizer.state {
        case .possible, .began:
            // Adjust the anchor point to scale the image around a finger
            let location = recognizer.location(in: panningImageView)
            let anchorPoint = CGPoint(x: location.x / panningImageView.frame.width,
                                      y: location.y / panningImageView.frame.height)
            panningImageView.updateAnchorPointWithoutMoving(anchorPoint)
        case .changed:
            let translation = recognizer.translation(in: currentPageView)
            let transitionProgress = translation.y / currentPageView.bounds.height
            
            animator.fractionComplete = transitionProgress
            transitionContext.updateInteractiveTransition(transitionProgress)
            
            let imageScale = min(1 - transitionProgress / 5, 1)
            panningImageView.transform = .init(translationX: translation.x, y: translation.y)
                .scaledBy(x: imageScale, y: imageScale)
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
}
