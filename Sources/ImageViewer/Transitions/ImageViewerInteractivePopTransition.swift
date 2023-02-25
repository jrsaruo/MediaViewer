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
    private var onePageImageFrameInContainerBackup = CGRect.null
    
    // MARK: - Initializers
    
    init(sourceThumbnailView: UIImageView) {
        self.sourceThumbnailView = sourceThumbnailView
        super.init()
    }
}

extension ImageViewerInteractivePopTransition: UIViewControllerInteractiveTransitioning {
    
    func startInteractiveTransition(_ transitionContext: any UIViewControllerContextTransitioning) {
        guard let onePageView = transitionContext.view(forKey: .from) as? ImageViewerOnePageView,
              let toView = transitionContext.view(forKey: .to) else {
            preconditionFailure("\(Self.self) works only with the pop animation for ImageViewerViewController.")
        }
        self.transitionContext = transitionContext
        let containerView = transitionContext.containerView
        let onePageImageView = onePageView.imageView
        
        // Back up
        thumbnailHiddenBackup = sourceThumbnailView.isHidden
        onePageImageFrameInContainerBackup = containerView.convert(onePageImageView.frame,
                                                                   from: onePageImageView)
        
        // Prepare for transition
        onePageView.destroyLayoutConfigurationBeforeTransition()
        onePageImageView.frame = onePageImageFrameInContainerBackup
        
        containerView.addSubview(toView)
        containerView.addSubview(onePageView)
        containerView.addSubview(onePageImageView)
        
        sourceThumbnailView.isHidden = true
        
        // Animation
        animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1) {
            onePageView.alpha = 0
        }
    }
    
    private func finishInteractiveTransition() {
        guard let animator, let transitionContext else { return }
        transitionContext.finishInteractiveTransition()
        
        let duration = 0.35
        animator.continueAnimation(withTimingParameters: nil, durationFactor: duration)
        
        let containerView = transitionContext.containerView
        let onePageView = onePageView(from: transitionContext)
        let onePageImageView = onePageView.imageView
        
        let finishAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
            let thumbnailFrameInContainer = containerView.convert(self.sourceThumbnailView.frame,
                                                                  from: self.sourceThumbnailView)
            onePageImageView.frame = thumbnailFrameInContainer
            onePageImageView.transitioningConfiguration = self.sourceThumbnailView.transitioningConfiguration
            onePageImageView.layer.masksToBounds = true // TODO: Change according to the thumbnail configuration
        }
        finishAnimator.addCompletion { _ in
            self.sourceThumbnailView.isHidden = self.thumbnailHiddenBackup
            onePageView.removeFromSuperview()
            onePageImageView.removeFromSuperview()
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
        
        let onePageView = onePageView(from: transitionContext)
        let onePageImageView = onePageView.imageView
        
        let cancelAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
            onePageImageView.frame = self.onePageImageFrameInContainerBackup
        }
        cancelAnimator.addCompletion { _ in
            // Restore to pre-transition state
            self.sourceThumbnailView.isHidden = self.thumbnailHiddenBackup
            onePageImageView.updateAnchorPointWithoutMoving(.init(x: 0.5, y: 0.5))
            onePageImageView.transform = .identity
            onePageView.restoreLayoutConfigurationAfterTransition()
            
            transitionContext.completeTransition(false)
        }
        cancelAnimator.startAnimation()
    }
    
    private func onePageView(from transitionContext: any UIViewControllerContextTransitioning) -> ImageViewerOnePageView {
        guard let onePageView = transitionContext.view(forKey: .from) as? ImageViewerOnePageView else {
            preconditionFailure("\(Self.self) works only with the pop animation for ImageViewerViewController.")
        }
        return onePageView
    }
    
    func panRecognized(by recognizer: UIPanGestureRecognizer) {
        guard let onePageView = recognizer.view as? ImageViewerOnePageView else {
            preconditionFailure("\(Self.self) works only with the pop animation for ImageViewerViewController.")
        }
        let panningImageView = onePageView.imageView
        
        switch recognizer.state {
        case .possible, .began:
            // Adjust the anchor point to scale the image around a finger
            let location = recognizer.location(in: panningImageView)
            let anchorPoint = CGPoint(x: location.x / panningImageView.frame.width,
                                      y: location.y / panningImageView.frame.height)
            panningImageView.updateAnchorPointWithoutMoving(anchorPoint)
        case .changed:
            guard let animator, let transitionContext else {
                // NOTE: Sometimes this method is called before startInteractiveTransition(_:) and enters here.
                return
            }
            let translation = recognizer.translation(in: onePageView)
            let transitionProgress = translation.y / onePageView.bounds.height
            
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
