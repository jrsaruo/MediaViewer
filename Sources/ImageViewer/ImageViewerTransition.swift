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
        let configurationBackup = imageViewerImageView.configuration
        let imageViewerImageFrameInContainer = containerView.convert(imageViewerImageView.frame,
                                                                     from: imageViewerImageView)
        let thumbnailFrameInContainer = containerView.convert(sourceThumbnailView.frame,
                                                              from: sourceThumbnailView)
        imageViewerView.destroyLayoutConfigurationBeforeTransition()
        imageViewerImageView.configuration = sourceThumbnailView.configuration
        imageViewerImageView.frame = thumbnailFrameInContainer
        imageViewerImageView.layer.masksToBounds = true
        containerView.addSubview(imageViewerImageView)
        sourceThumbnailView.isHidden = true
        
        // Animation
        let duration = transitionDuration(using: transitionContext)
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.72) {
            imageViewerView.alpha = 1
            imageViewerImageView.frame = imageViewerImageFrameInContainer
            imageViewerImageView.configuration = configurationBackup
            
            // NOTE: Keep following properties during transition for smooth animation
            imageViewerImageView.contentMode = self.sourceThumbnailView.contentMode
            imageViewerImageView.layer.masksToBounds = true
        }
        animator.addCompletion { position in
            switch position {
            case .end:
                imageViewerImageView.configuration = configurationBackup
                imageViewerView.restoreLayoutConfigurationAfterTransition()
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
        
        let imageViewerImageView = imageViewer.imageViewerView.imageView
        let imageViewerImageFrameInContainer = containerView.convert(imageViewerImageView.frame,
                                                                     from: imageViewerImageView)
        let thumbnailFrameInContainer = containerView.convert(sourceThumbnailView.frame,
                                                              from: sourceThumbnailView)
        imageViewer.imageViewerView.destroyLayoutConfigurationBeforeTransition()
        imageViewerImageView.frame = imageViewerImageFrameInContainer
        containerView.addSubview(imageViewerImageView)
        sourceThumbnailView.isHidden = true
        
        // Animation
        let duration = transitionDuration(using: transitionContext)
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
            toView.alpha = 1
            imageViewerImageView.frame = thumbnailFrameInContainer
            imageViewerImageView.configuration = self.sourceThumbnailView.configuration
            imageViewerImageView.clipsToBounds = true // TODO: Change according to the thumbnail configuration
        }
        animator.addCompletion { position in
            switch position {
            case .end:
                imageViewerImageView.removeFromSuperview()
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

private struct UIImageViewConfiguration {
    var backgroundColor: UIColor?
    var tintColor: UIColor?
    var contentMode: UIView.ContentMode
    var cornerRadius: CGFloat
    var borderColor: CGColor?
    var borderWidth: CGFloat
    var masksToBounds: Bool
}

extension UIImageView {
    
    fileprivate var configuration: UIImageViewConfiguration {
        get {
            .init(backgroundColor: backgroundColor,
                  tintColor: tintColor,
                  contentMode: contentMode,
                  cornerRadius: layer.cornerRadius,
                  borderColor: layer.borderColor,
                  borderWidth: layer.borderWidth,
                  masksToBounds: layer.masksToBounds)
        }
        set {
            backgroundColor = newValue.backgroundColor
            tintColor = newValue.tintColor
            contentMode = newValue.contentMode
            layer.cornerRadius = newValue.cornerRadius
            layer.borderColor = newValue.borderColor
            layer.borderWidth = newValue.borderWidth
            layer.masksToBounds = newValue.masksToBounds
        }
    }
}
