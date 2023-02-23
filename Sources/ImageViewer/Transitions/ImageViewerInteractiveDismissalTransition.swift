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
        
        // Back up
        let thumbnailHiddenBackup = sourceThumbnailView.isHidden
        
        // Prepare for transition
        let imageViewerImageView = imageViewerView.imageView
        let imageViewerImageFrameInContainer = containerView.convert(imageViewerImageView.frame,
                                                                     from: imageViewerImageView)
        
        imageViewerView.destroyLayoutConfigurationBeforeTransition()
        imageViewerImageView.frame = imageViewerImageFrameInContainer
        
        containerView.addSubview(toView)
        containerView.addSubview(imageViewerView)
        containerView.addSubview(imageViewerImageView)
        
        sourceThumbnailView.isHidden = true
        
        // Animation
        animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1) {
            imageViewerView.alpha = 0
        }
        animator!.addCompletion { [weak self] position in
            guard let self else {
                transitionContext.completeTransition(true)
                return
            }
            
            switch position {
            case .end:
                transitionContext.finishInteractiveTransition()
                let finishAnimator = UIViewPropertyAnimator(duration: 0.35, dampingRatio: 1) {
                    let thumbnailFrameInContainer = containerView.convert(self.sourceThumbnailView.frame,
                                                                          from: self.sourceThumbnailView)
                    imageViewerImageView.frame = thumbnailFrameInContainer
                    imageViewerImageView.transitioningConfiguration = self.sourceThumbnailView.transitioningConfiguration
                    imageViewerImageView.layer.masksToBounds = true // TODO: Change according to the thumbnail configuration
                }
                finishAnimator.addCompletion { _ in
                    self.sourceThumbnailView.isHidden = thumbnailHiddenBackup
                    imageViewerView.removeFromSuperview()
                    imageViewerImageView.removeFromSuperview()
                    transitionContext.completeTransition(true)
                }
                finishAnimator.startAnimation()
            case .start:
                transitionContext.cancelInteractiveTransition()
                let cancelAnimator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1) {
                    imageViewerImageView.frame = imageViewerImageFrameInContainer
                }
                cancelAnimator.addCompletion { _ in
                    self.sourceThumbnailView.isHidden = thumbnailHiddenBackup
                    imageViewerImageView.transform = .identity
                    imageViewerView.restoreLayoutConfigurationAfterTransition()
                    transitionContext.completeTransition(false)
                }
                cancelAnimator.startAnimation()
            case .current:
                assertionFailure()
            @unknown default:
                assertionFailure("Unknown position: \(position)")
            }
        }
    }
    
    func panRecognized(by recognizer: UIPanGestureRecognizer) {
        guard let imageViewerView = recognizer.view as? ImageViewerView else {
            preconditionFailure("\(Self.self) works only with the pop animation for ImageViewerViewController.")
        }
        guard let animator, let transitionContext else {
            assertionFailure("Transition should have started.")
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
                animator.stopAnimation(false)
                animator.finishAnimation(at: .end)
            } else {
                animator.stopAnimation(false)
                animator.finishAnimation(at: .start)
            }
        case .cancelled, .failed:
            animator.stopAnimation(false)
            animator.finishAnimation(at: .start)
        @unknown default:
            assertionFailure()
        }
    }
}
