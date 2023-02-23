//
//  ImageViewerInteractiveDismissalTransition.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/23.
//

import UIKit

final class ImageViewerInteractiveDismissalTransition: NSObject {
    
    private let sourceThumbnailView: UIImageView
    
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
        let animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1) {
            imageViewerView.alpha = 0
        }
        animator.addCompletion { position in
            self.sourceThumbnailView.isHidden = thumbnailHiddenBackup
            imageViewerView.removeFromSuperview()
            imageViewerImageView.removeFromSuperview()
            transitionContext.finishInteractiveTransition()
            transitionContext.completeTransition(true)
        }
        animator.startAnimation()
    }
    
    func panRecognized(by recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .possible, .began:
            break
        case .changed:
            break // TODO: Update transition progress
        case .ended:
            break // TODO: Finish or cancel transition
        case .cancelled, .failed:
            break // TODO: Cancel transition
        @unknown default:
            assertionFailure()
        }
    }
}
