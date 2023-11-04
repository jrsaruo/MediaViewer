//
//  MediaViewerInteractivePopTransition.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/23.
//

import UIKit

@MainActor
final class MediaViewerInteractivePopTransition: NSObject {
    
    private let sourceView: UIView?
    
    private var animator: UIViewPropertyAnimator?
    private var transitionContext: (any UIViewControllerContextTransitioning)?
    
    private var shouldAnimateTabBar = false
    
    private var tabBar: UITabBar? {
        transitionContext?.viewController(forKey: .to)?.tabBarController?.tabBar
    }
    
    // MARK: Backups
    
    private var sourceViewHiddenBackup = false
    private var tabBarScrollEdgeAppearanceBackup: UITabBarAppearance?
    private var tabBarAlphaBackup: CGFloat?
    private var toVCToolbarItemsBackup: [UIBarButtonItem]?
    private var initialZoomScale: CGFloat = 1
    private var initialImageTransform = CGAffineTransform.identity
    private var initialImageFrameInViewer = CGRect.null
    
    // MARK: - Initializers
    
    init(sourceView: UIView?) {
        self.sourceView = sourceView
        super.init()
    }
}

extension MediaViewerInteractivePopTransition: UIViewControllerInteractiveTransitioning {
    
    func startInteractiveTransition(
        _ transitionContext: any UIViewControllerContextTransitioning
    ) {
        guard let mediaViewer = transitionContext.viewController(forKey: .from) as? MediaViewerViewController,
              let mediaViewerView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to),
              let toVC = transitionContext.viewController(forKey: .to),
              let navigationController = mediaViewer.navigationController
        else {
            preconditionFailure(
                "\(Self.self) works only with the pop animation for \(MediaViewerViewController.self)."
            )
        }
        self.transitionContext = transitionContext
        let containerView = transitionContext.containerView
        let currentPageView = mediaViewerCurrentPageView(in: transitionContext)
        let currentPageImageView = currentPageView.imageView
        
        // Back up
        sourceViewHiddenBackup = sourceView?.isHidden ?? false
        tabBarScrollEdgeAppearanceBackup = tabBar?.scrollEdgeAppearance
        tabBarAlphaBackup = tabBar?.alpha
        toVCToolbarItemsBackup = toVC.toolbarItems
        initialZoomScale = currentPageView.scrollView.zoomScale
        initialImageTransform = currentPageImageView.transform
        initialImageFrameInViewer = mediaViewerView.convert(
            currentPageImageView.frame,
            from: currentPageView.scrollView
        )
        
        // MARK: Prepare for the transition
        
        currentPageView.destroyLayoutConfigurationBeforeTransition()
        currentPageImageView.frame = initialImageFrameInViewer
        
        toView.frame = transitionContext.finalFrame(for: toVC)
        containerView.addSubview(toView)
        containerView.addSubview(mediaViewerView)
        mediaViewer.insertImageViewForTransition(currentPageImageView)
        
        sourceView?.isHidden = true
        
        if let tabBar {
            // Make tabBar opaque during the transition
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            tabBar.scrollEdgeAppearance = appearance
        }
        
        /*
         * NOTE:
         * If the navigation bar is hidden on transition start, some animations
         * are applied by system and the bar remains hidden after the transition.
         * Removed those animations to avoid this problem.
         */
        let navigationBar = navigationController.navigationBar
        if let animationKeys = navigationBar.layer.animationKeys() {
            assert(animationKeys.allSatisfy {
                $0.starts(with: "opacity")
                || $0.starts(with: "UIPacingAnimationForAnimatorsKey")
            })
            navigationBar.layer.removeAllAnimations()
        }
        navigationBar.alpha = mediaViewer.isShowingMediaOnly 
        ? 0.0001 // NOTE: .leastNormalMagnitude didn't work.
        : 1
        
        // [Workaround] Prevent toVC.toolbarItems from showing up during transition.
        toVC.toolbarItems = nil
        
        let pageControlToolbar = mediaViewer.pageControlToolbar
        let pageControlToolbarFrame = pageControlToolbar.frame
        // Disable AutoLayout
        pageControlToolbar.translatesAutoresizingMaskIntoConstraints = true
        
        mediaViewer.willStartInteractivePopTransition()
        
        // MARK: Animation
        
        animator = UIViewPropertyAnimator(duration: 0.25, dampingRatio: 1) {
            navigationBar.alpha = mediaViewer.navigationBarAlphaBackup
            for subview in mediaViewer.subviewsToFadeDuringTransition {
                subview.alpha = 0
            }
            
            /*
             * [Workaround]
             * AutoLayout didn't work. If changed layout constraints before animation,
             * they are applied at a moment because animator doesn't start immediately.
             *
             * NOTE:
             * Changing frame.origin.y and frame.size.height separately causes
             * animation bug so frame should be updated at once.
             */
            pageControlToolbar.frame = CGRect(
                x: pageControlToolbarFrame.minX,
                y: pageControlToolbarFrame.maxY,
                width: pageControlToolbarFrame.width,
                height: 0
            )
        }
    }
    
    private func finishInteractiveTransition() {
        guard let animator, let transitionContext else { return }
        transitionContext.finishInteractiveTransition()
        
        animator.continueAnimation(withTimingParameters: nil, durationFactor: 1)
        
        let mediaViewerView = transitionContext.view(forKey: .from)!
        let currentPageView = mediaViewerCurrentPageView(in: transitionContext)
        let currentPageImageView = currentPageView.imageView
        
        tabBar?.scrollEdgeAppearance = tabBarScrollEdgeAppearanceBackup
        
        let finishAnimator = UIViewPropertyAnimator(duration: 0.35, dampingRatio: 1) {
            if let sourceView = self.sourceView {
                let sourceFrameInViewer = mediaViewerView.convert(
                    sourceView.frame,
                    from: sourceView
                )
                currentPageImageView.frame = sourceFrameInViewer
                currentPageImageView.transitioningConfiguration = sourceView.transitioningConfiguration
                currentPageImageView.layer.masksToBounds = true // TODO: Change according to the source configuration
            } else {
                currentPageImageView.alpha = 0
            }
            
            if self.shouldAnimateTabBar {
                self.tabBar?.alpha = 1
            }
        }
        
        let mediaViewer = transitionContext.viewController(forKey: .from) as! MediaViewerViewController
        let toVC = transitionContext.viewController(forKey: .to)!
        let navigationController = toVC.navigationController!
        let toolbar = navigationController.toolbar!
        
        finishAnimator.addCompletion { _ in
            self.sourceView?.isHidden = self.sourceViewHiddenBackup
            currentPageView.removeFromSuperview()
            currentPageImageView.removeFromSuperview()
            
            toVC.toolbarItems = self.toVCToolbarItemsBackup
            navigationController.isToolbarHidden = mediaViewer.toolbarHiddenBackup
            toolbar.scrollEdgeAppearance = mediaViewer.toolbarScrollEdgeAppearanceBackup
            
            // Disable the default animation applied to the toolbar
            if let animationKeys = toolbar.layer.animationKeys() {
                assert(animationKeys.allSatisfy { $0.starts(with: "position") })
                toolbar.layer.removeAllAnimations()
            }
            
            transitionContext.completeTransition(true)
        }
        finishAnimator.startAnimation()
    }
    
    private func cancelInteractiveTransition() {
        guard let animator, let transitionContext else { return }
        transitionContext.cancelInteractiveTransition()
        
        animator.isReversed = true
        animator.continueAnimation(withTimingParameters: nil, durationFactor: 1)
        
        let mediaViewer = transitionContext.viewController(forKey: .from) as! MediaViewerViewController
        let currentPageView = mediaViewerCurrentPageView(in: transitionContext)
        let currentPageImageView = currentPageView.imageView
        let toVC = transitionContext.viewController(forKey: .to)!
        
        let cancelAnimator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1) {
            // FIXME: toolbar items go away during animation
            currentPageImageView.frame = self.initialImageFrameInViewer
            
            if self.shouldAnimateTabBar {
                self.tabBar?.alpha = 0
            }
        }
        cancelAnimator.addCompletion { _ in
            // Restore to pre-transition state
            self.sourceView?.isHidden = self.sourceViewHiddenBackup
            currentPageImageView.updateAnchorPointWithoutMoving(.init(x: 0.5, y: 0.5))
            currentPageImageView.transform = self.initialImageTransform
            currentPageView.restoreLayoutConfigurationAfterTransition()
            
            self.tabBar?.scrollEdgeAppearance = self.tabBarScrollEdgeAppearanceBackup
            if let tabBarAlphaBackup = self.tabBarAlphaBackup {
                self.tabBar?.alpha = tabBarAlphaBackup
            }
            
            toVC.toolbarItems = self.toVCToolbarItemsBackup
            
            let pageControlToolbar = mediaViewer.pageControlToolbar
            pageControlToolbar.translatesAutoresizingMaskIntoConstraints = false
            mediaViewer.didCancelInteractivePopTransition()
            let toolbar = toVC.navigationController!.toolbar!
            toolbar.scrollEdgeAppearance = mediaViewer.toolbarScrollEdgeAppearanceBackup
            
            transitionContext.completeTransition(false)
        }
        cancelAnimator.startAnimation()
    }
    
    private func mediaViewerCurrentPageView(
        in transitionContext: some UIViewControllerContextTransitioning
    ) -> MediaViewerOnePageView {
        guard let mediaViewer = transitionContext.viewController(forKey: .from) as? MediaViewerViewController else {
            preconditionFailure(
                "\(Self.self) works only with the pop animation for \(MediaViewerViewController.self)."
            )
        }
        return mediaViewer.currentPageViewController.mediaViewerOnePageView
    }
    
    func panRecognized(
        by recognizer: UIPanGestureRecognizer,
        in mediaViewer: MediaViewerViewController
    ) {
        let currentPageView = mediaViewer.currentPageViewController.mediaViewerOnePageView
        let panningImageView = currentPageView.imageView
        
        if let tabBar, tabBar.layer.animationKeys() != nil {
            // Disable the default animation applied to the tabBar
            tabBar.layer.removeAllAnimations()
            
            /*
             * NOTE:
             * If the animation is applied to the tabBar by system,
             * it should be animated.
             */
            shouldAnimateTabBar = true
        }
        
        switch recognizer.state {
        case .possible, .began:
            // Adjust the anchor point to scale the image around a finger
            let location = recognizer.location(in: currentPageView.scrollView)
            let anchorPoint = CGPoint(
                x: location.x / panningImageView.frame.width,
                y: location.y / panningImageView.frame.height
            )
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
            
            if shouldAnimateTabBar {
                tabBar?.alpha = transitionProgress
            }
            
            panningImageView.transform = panningImageTransform(
                translation: translation,
                panAreaSize: panAreaSize
            )
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
    private func panningImageTransform(
        translation: CGPoint,
        panAreaSize: CGSize
    ) -> CGAffineTransform {
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
            .translatedBy(
                x: translationX / initialZoomScale,
                y: translationY / initialZoomScale
            )
            .scaledBy(x: imageScale, y: imageScale)
    }
    
    private func easeOutQuadratic(_ x: Double) -> Double {
        -x * (x - 2)
    }
}
