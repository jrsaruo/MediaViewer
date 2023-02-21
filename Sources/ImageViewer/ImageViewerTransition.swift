//
//  ImageViewerTransition.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/21.
//

import UIKit

final class ImageViewerTransition: NSObject, UIViewControllerAnimatedTransitioning {
    
    let operation: UINavigationController.Operation
    let sourceThumbnailView: UIImageView
    
    // MARK: - Initializers
    
    init(operation: UINavigationController.Operation,
         sourceThumbnailView: UIImageView) {
        self.operation = operation
        self.sourceThumbnailView = sourceThumbnailView
    }
    
    // MARK: - Methods
    
    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        switch operation {
        case .push:
            return 0.45
        case .pop:
            return 0.35
        case .none:
            return 0.3
        @unknown default:
            return 0.3
        }
    }
    
    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        switch operation {
        case .push:
            animatePushTransition(using: transitionContext)
        case .pop:
            animatePopTransition(using: transitionContext)
        case .none:
            fatalError("Not implemented.")
        @unknown default:
            fatalError("Not implemented.")
        }
    }
    
    private func animatePushTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        guard let imageViewer = transitionContext.viewController(forKey: .to) as? ImageViewerViewController,
              let imageViewerView = transitionContext.view(forKey: .to) as? ImageViewerView
        else {
            assertionFailure("\(Self.self) works only with the push/pop animation for ImageViewerViewController.")
            transitionContext.completeTransition(false)
            return
        }
        let containerView = transitionContext.containerView
        containerView.addSubview(imageViewerView)
        
        // Back up
        let thumbnailHiddenBackup = sourceThumbnailView.isHidden
        
        // Prepare for transition
        imageViewerView.frame = transitionContext.finalFrame(for: imageViewer)
        imageViewerView.alpha = 0
        imageViewerView.layoutIfNeeded()
        
        let imageViewerImageView = imageViewerView.imageView
        let imageViewerImageFrameInContainer = containerView.convert(imageViewerImageView.frame,
                                                                     from: imageViewerImageView)
        let thumbnailFrameInContainer = containerView.convert(sourceThumbnailView.frame,
                                                              from: sourceThumbnailView)
        imageViewerView.destroyConfigurationsBeforeTransition()
        imageViewerImageView.frame = thumbnailFrameInContainer
        imageViewerImageView.contentMode = sourceThumbnailView.contentMode
        containerView.addSubview(imageViewerImageView)
        sourceThumbnailView.isHidden = true
        
        // Animation
        let duration = transitionDuration(using: transitionContext)
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.72) {
            imageViewerView.alpha = 1
            imageViewerImageView.frame = imageViewerImageFrameInContainer
        }
        animator.addCompletion { [weak self] position in
            switch position {
            case .end:
                imageViewerView.restoreConfigurationsAfterTransition()
                self?.sourceThumbnailView.isHidden = thumbnailHiddenBackup
                transitionContext.completeTransition(true)
            case .start, .current:
                assertionFailure()
                break
            @unknown default:
                transitionContext.completeTransition(false)
            }
        }
        animator.startAnimation()
    }
    
    private func animatePopTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        guard let imageViewer = transitionContext.viewController(forKey: .from) as? ImageViewerViewController,
              let toView = transitionContext.view(forKey: .to),
              let toVC = transitionContext.viewController(forKey: .to)
        else {
            assertionFailure("\(Self.self) works only with the push/pop animation for ImageViewerViewController.")
            transitionContext.completeTransition(false)
            return
        }
        let containerView = transitionContext.containerView
        containerView.addSubview(toView)
        
        // Back up
        let thumbnailHiddenBackup = sourceThumbnailView.isHidden
        
        // Prepare for transition
        toView.frame = transitionContext.finalFrame(for: toVC)
        toView.alpha = 0
        toVC.view.layoutIfNeeded()
        
        let imageViewerImageView = imageViewer.imageViewerView.imageView
        let imageViewerImageFrameInContainer = containerView.convert(imageViewerImageView.frame,
                                                                     from: imageViewerImageView)
        let thumbnailFrameInContainer = containerView.convert(sourceThumbnailView.frame,
                                                              from: sourceThumbnailView)
        imageViewer.imageViewerView.destroyConfigurationsBeforeTransition()
        imageViewerImageView.frame = imageViewerImageFrameInContainer
        containerView.addSubview(imageViewerImageView)
        sourceThumbnailView.isHidden = true
        
        // Animation
        let duration = transitionDuration(using: transitionContext)
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) { [weak self] in
            guard let self else { return }
            toView.alpha = 1
            imageViewerImageView.frame = thumbnailFrameInContainer
            imageViewerImageView.contentMode = self.sourceThumbnailView.contentMode
            imageViewerImageView.clipsToBounds = true // TODO: Change according to the thumbnail configuration
        }
        animator.addCompletion { [weak self] position in
            switch position {
            case .end:
                imageViewerImageView.removeFromSuperview()
                self?.sourceThumbnailView.isHidden = thumbnailHiddenBackup
                transitionContext.completeTransition(true)
            case .start, .current:
                assertionFailure()
                break
            @unknown default:
                transitionContext.completeTransition(false)
            }
        }
        animator.startAnimation()
    }
}
