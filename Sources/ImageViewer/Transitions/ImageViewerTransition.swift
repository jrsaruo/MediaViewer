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
              let imageViewerView = transitionContext.view(forKey: .to)
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
        let onePageView = imageViewer.currentPageViewController.imageViewerOnePageView
        onePageView.frame = transitionContext.finalFrame(for: imageViewer)
        onePageView.alpha = 0
        onePageView.layoutIfNeeded()
        
        let onePageImageView = onePageView.imageView
        let configurationBackup = onePageImageView.transitioningConfiguration
        let onePageImageFrameInContainer = containerView.convert(onePageImageView.frame,
                                                                 from: onePageImageView)
        let thumbnailFrameInContainer = containerView.convert(sourceThumbnailView.frame,
                                                              from: sourceThumbnailView)
        onePageView.destroyLayoutConfigurationBeforeTransition()
        onePageImageView.transitioningConfiguration = sourceThumbnailView.transitioningConfiguration
        onePageImageView.frame = thumbnailFrameInContainer
        onePageImageView.layer.masksToBounds = true
        containerView.addSubview(onePageImageView)
        sourceThumbnailView.isHidden = true
        
        // Animation
        let duration = transitionDuration(using: transitionContext)
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.72) {
            onePageView.alpha = 1
            onePageImageView.frame = onePageImageFrameInContainer
            onePageImageView.transitioningConfiguration = configurationBackup
            
            // NOTE: Keep following properties during transition for smooth animation
            onePageImageView.contentMode = self.sourceThumbnailView.contentMode
            onePageImageView.layer.masksToBounds = true
        }
        animator.addCompletion { position in
            switch position {
            case .end:
                onePageImageView.transitioningConfiguration = configurationBackup
                onePageView.restoreLayoutConfigurationAfterTransition()
                self.sourceThumbnailView.isHidden = thumbnailHiddenBackup
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
        
        let onePageView = imageViewer.currentPageViewController.imageViewerOnePageView
        let onePageImageView = onePageView.imageView
        let imageViewerImageFrameInContainer = containerView.convert(onePageImageView.frame,
                                                                     from: onePageImageView)
        let thumbnailFrameInContainer = containerView.convert(sourceThumbnailView.frame,
                                                              from: sourceThumbnailView)
        onePageView.destroyLayoutConfigurationBeforeTransition()
        onePageImageView.frame = imageViewerImageFrameInContainer
        containerView.addSubview(onePageImageView)
        sourceThumbnailView.isHidden = true
        
        // Animation
        let duration = transitionDuration(using: transitionContext)
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
            toView.alpha = 1
            onePageImageView.frame = thumbnailFrameInContainer
            onePageImageView.transitioningConfiguration = self.sourceThumbnailView.transitioningConfiguration
            onePageImageView.clipsToBounds = true // TODO: Change according to the thumbnail configuration
        }
        animator.addCompletion { position in
            switch position {
            case .end:
                onePageImageView.removeFromSuperview()
                self.sourceThumbnailView.isHidden = thumbnailHiddenBackup
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
