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
            return 0.5
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
            assertionFailure("\(Self.self) works only with the push/pop animation for \(ImageViewerViewController.self).")
            transitionContext.completeTransition(false)
            return
        }
        let containerView = transitionContext.containerView
        containerView.addSubview(imageViewerView)
        
        // Back up
        let thumbnailHiddenBackup = sourceThumbnailView.isHidden
        
        // Prepare for transition
        let currentPageView = imageViewer.currentPageViewController.imageViewerOnePageView
        currentPageView.frame = transitionContext.finalFrame(for: imageViewer)
        currentPageView.alpha = 0
        currentPageView.layoutIfNeeded()
        
        let currentPageImageView = currentPageView.imageView
        let configurationBackup = currentPageImageView.transitioningConfiguration
        let currentPageImageFrameInContainer = containerView.convert(currentPageImageView.frame,
                                                                     from: currentPageImageView)
        let thumbnailFrameInContainer = containerView.convert(sourceThumbnailView.frame,
                                                              from: sourceThumbnailView)
        currentPageView.destroyLayoutConfigurationBeforeTransition()
        currentPageImageView.transitioningConfiguration = sourceThumbnailView.transitioningConfiguration
        currentPageImageView.frame = thumbnailFrameInContainer
        currentPageImageView.layer.masksToBounds = true
        containerView.addSubview(currentPageImageView)
        sourceThumbnailView.isHidden = true
        
        // Animation
        let duration = transitionDuration(using: transitionContext)
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.68) {
            currentPageView.alpha = 1
            currentPageImageView.frame = currentPageImageFrameInContainer
            currentPageImageView.transitioningConfiguration = configurationBackup
            
            // NOTE: Keep following properties during transition for smooth animation
            currentPageImageView.contentMode = self.sourceThumbnailView.contentMode
            currentPageImageView.layer.masksToBounds = true
        }
        animator.addCompletion { position in
            switch position {
            case .end:
                currentPageImageView.transitioningConfiguration = configurationBackup
                currentPageView.restoreLayoutConfigurationAfterTransition()
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
            assertionFailure("\(Self.self) works only with the push/pop animation for \(ImageViewerViewController.self).")
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
        
        let currentPageView = imageViewer.currentPageViewController.imageViewerOnePageView
        let currentPageImageView = currentPageView.imageView
        let currentPageImageFrameInContainer = containerView.convert(currentPageImageView.frame,
                                                                     from: currentPageImageView)
        let thumbnailFrameInContainer = containerView.convert(sourceThumbnailView.frame,
                                                              from: sourceThumbnailView)
        currentPageView.destroyLayoutConfigurationBeforeTransition()
        currentPageImageView.frame = currentPageImageFrameInContainer
        containerView.addSubview(currentPageImageView)
        sourceThumbnailView.isHidden = true
        
        // Animation
        let duration = transitionDuration(using: transitionContext)
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
            toView.alpha = 1
            currentPageImageView.frame = thumbnailFrameInContainer
            currentPageImageView.transitioningConfiguration = self.sourceThumbnailView.transitioningConfiguration
            currentPageImageView.clipsToBounds = true // TODO: Change according to the thumbnail configuration
        }
        animator.addCompletion { position in
            switch position {
            case .end:
                currentPageImageView.removeFromSuperview()
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
