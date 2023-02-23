//
//  ImageViewerInteractiveDismissalTransition.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/23.
//

import UIKit

final class ImageViewerInteractiveDismissalTransition: NSObject {
    
    private let sourceThumbnailView: UIImageView
    
    private var animator: UIViewPropertyAnimator?
    private var transitionContext: (any UIViewControllerContextTransitioning)?
    
    // MARK: Backups
    
    private var thumbnailHiddenBackup = false
    private var imageViewerImageFrameInContainerBackup = CGRect.null
    
    // MARK: - Initializers
    
    init(sourceThumbnailView: UIImageView) {
        self.sourceThumbnailView = sourceThumbnailView
        super.init()
    }
}

extension ImageViewerInteractiveDismissalTransition: UIViewControllerInteractiveTransitioning {
    
    func startInteractiveTransition(_ transitionContext: any UIViewControllerContextTransitioning) {
        guard let imageViewerView = transitionContext.view(forKey: .from) as? ImageViewerView,
              let toView = transitionContext.view(forKey: .to) else {
            preconditionFailure("\(Self.self) works only with the pop animation for ImageViewerViewController.")
        }
        self.transitionContext = transitionContext
        let containerView = transitionContext.containerView
        let imageViewerImageView = imageViewerView.imageView
        
        // Back up
        thumbnailHiddenBackup = sourceThumbnailView.isHidden
        imageViewerImageFrameInContainerBackup = containerView.convert(imageViewerImageView.frame,
                                                                       from: imageViewerImageView)
        
        // Prepare for transition
        
        imageViewerView.destroyLayoutConfigurationBeforeTransition()
        imageViewerImageView.frame = imageViewerImageFrameInContainerBackup
        
        containerView.addSubview(toView)
        containerView.addSubview(imageViewerView)
        containerView.addSubview(imageViewerImageView)
        
        sourceThumbnailView.isHidden = true
        
        // Animation
        animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1) {
            imageViewerView.alpha = 0
        }
    }
    
    private func finishInteractiveTransition() {
        guard let animator, let transitionContext else { return }
        transitionContext.finishInteractiveTransition()
        
        let duration = 0.35
        animator.continueAnimation(withTimingParameters: nil, durationFactor: duration)
        
        let containerView = transitionContext.containerView
        let imageViewerView = imageViewerView(from: transitionContext)
        let imageViewerImageView = imageViewerView.imageView
        
        let finishAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
            let thumbnailFrameInContainer = containerView.convert(self.sourceThumbnailView.frame,
                                                                  from: self.sourceThumbnailView)
            imageViewerImageView.frame = thumbnailFrameInContainer
            imageViewerImageView.transitioningConfiguration = self.sourceThumbnailView.transitioningConfiguration
            imageViewerImageView.layer.masksToBounds = true // TODO: Change according to the thumbnail configuration
        }
        finishAnimator.addCompletion { _ in
            self.sourceThumbnailView.isHidden = self.thumbnailHiddenBackup
            imageViewerView.removeFromSuperview()
            imageViewerImageView.removeFromSuperview()
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
        
        let imageViewerView = imageViewerView(from: transitionContext)
        let imageViewerImageView = imageViewerView.imageView
        
        let cancelAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
            imageViewerImageView.frame = self.imageViewerImageFrameInContainerBackup
        }
        cancelAnimator.addCompletion { _ in
            self.sourceThumbnailView.isHidden = self.thumbnailHiddenBackup
            imageViewerImageView.transform = .identity
            imageViewerView.restoreLayoutConfigurationAfterTransition()
            transitionContext.completeTransition(false)
        }
        cancelAnimator.startAnimation()
    }
    
    private func imageViewerView(from transitionContext: any UIViewControllerContextTransitioning) -> ImageViewerView {
        guard let imageViewerView = transitionContext.view(forKey: .from) as? ImageViewerView else {
            preconditionFailure("\(Self.self) works only with the pop animation for ImageViewerViewController.")
        }
        return imageViewerView
    }
    
    func panRecognized(by recognizer: UIPanGestureRecognizer) {
        guard let imageViewerView = recognizer.view as? ImageViewerView else {
            preconditionFailure("\(Self.self) works only with the pop animation for ImageViewerViewController.")
        }
        guard let animator, let transitionContext else {
            // NOTE: Sometimes this method is called before startInteractiveTransition(_:) and enters here.
            return
        }
        
        switch recognizer.state {
        case .possible, .began:
            break
        case .changed:
            let translation = recognizer.translation(in: imageViewerView)
            let transitionProgress = translation.y / imageViewerView.bounds.height
            
            animator.fractionComplete = transitionProgress
            transitionContext.updateInteractiveTransition(transitionProgress)
            
            let imageScale = min(1 - transitionProgress / 5, 1)
            let panningImageView = imageViewerView.imageView
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
