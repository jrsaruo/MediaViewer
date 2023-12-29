//
//  MediaViewerTransition.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/21.
//

import UIKit

@MainActor
final class MediaViewerTransition: NSObject, UIViewControllerAnimatedTransitioning {
    
    private let operation: UINavigationController.Operation
    private let sourceView: UIView?
    private let sourceImage: () -> UIImage?
    
    // MARK: - Initializers
    
    init(
        operation: UINavigationController.Operation,
        sourceView: UIView?,
        sourceImage: @escaping () -> UIImage?
    ) {
        self.operation = operation
        self.sourceView = sourceView
        self.sourceImage = sourceImage
    }
    
    // MARK: - Methods
    
    func transitionDuration(
        using transitionContext: (any UIViewControllerContextTransitioning)?
    ) -> TimeInterval {
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
    
    func animateTransition(
        using transitionContext: any UIViewControllerContextTransitioning
    ) {
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
    
    private func animatePushTransition(
        using transitionContext: some UIViewControllerContextTransitioning
    ) {
        guard let mediaViewer = transitionContext.viewController(forKey: .to) as? MediaViewerViewController,
              let mediaViewerView = transitionContext.view(forKey: .to),
              let navigationController = mediaViewer.navigationController
        else {
            preconditionFailure(
                "\(Self.self) works only with the push/pop animation for \(MediaViewerViewController.self)."
            )
        }
        let containerView = transitionContext.containerView
        containerView.addSubview(mediaViewerView)
        
        let tabBar = mediaViewer.tabBarController?.tabBar
        let navigationBar = navigationController.navigationBar
        
        // Back up
        let sourceViewHiddenBackup = sourceView?.isHidden ?? false
        let tabBarSuperviewBackup = tabBar?.superview
        let tabBarHiddenBackup = tabBar?.isHidden
        let tabBarScrollEdgeAppearanceBackup = tabBar?.scrollEdgeAppearance
        let navigationBarAlphaBackup = navigationBar.alpha
        
        // MARK: Prepare for the transition
        
        mediaViewerView.frame = transitionContext.finalFrame(for: mediaViewer)
        
        // Determine the layout of the destination before the transition
        mediaViewerView.layoutIfNeeded()
        
        let currentPageView = mediaViewer.currentPageViewController.mediaViewerOnePageView
        let currentPageImageView = currentPageView.imageView
        
        /*
         * NOTE:
         * If the image has not yet been fetched asynchronously,
         * animate the source image instead.
         */
        if currentPageImageView.image == nil,
           let sourceImage = sourceImage() {
            currentPageView.setImage(sourceImage, with: .none)
        }
        
        let configurationBackup = currentPageImageView.transitioningConfiguration
        let currentPageImageFrameInViewer = mediaViewerView.convert(
            currentPageImageView.frame,
            from: currentPageImageView
        )
        if let sourceView {
            // Match the appearance of the animating image view to the source
            let sourceFrameInViewer = mediaViewerView.convert(
                sourceView.frame,
                from: sourceView.superview
            )
            currentPageView.destroyLayoutConfigurationBeforeTransition()
            currentPageImageView.transitioningConfiguration = sourceView.transitioningConfiguration
            currentPageImageView.frame = sourceFrameInViewer
        } else {
            currentPageView.destroyLayoutConfigurationBeforeTransition()
            currentPageImageView.frame = currentPageImageFrameInViewer
        }
        currentPageImageView.layer.masksToBounds = true
        mediaViewer.insertImageViewForTransition(currentPageImageView)
        sourceView?.isHidden = true
        
        let wasTabBarHidden = mediaViewer.tabBarHiddenBackup ?? true
        if let tabBar {
            // Show the tabBar during the transition
            containerView.addSubview(tabBar)
            if !wasTabBarHidden {
                tabBar.isHidden = false
            }
            
            // Make the tabBar opaque during the transition
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            tabBar.scrollEdgeAppearance = appearance
            
            // Disable the default animation applied to the tabBar
            if mediaViewer.hidesBottomBarWhenPushed,
               let animationKeys = tabBar.layer.animationKeys() {
                assert(animationKeys.allSatisfy { $0.starts(with: "position") })
                tabBar.layer.removeAllAnimations()
            }
        }
        
        if mediaViewer.navigationBarHiddenBackup {
            navigationBar.alpha = 0
        }
        
        // Disable the default animation applied to the toolbar
        let toolbar = navigationController.toolbar!
        if let animationKeys = toolbar.layer.animationKeys() {
            assert(animationKeys.allSatisfy { $0.starts(with: "position") })
            toolbar.layer.removeAllAnimations()
        }
        
        var viewsToFadeDuringTransition = mediaViewer.subviewsToFadeDuringTransition
        if wasTabBarHidden {
            viewsToFadeDuringTransition.append(mediaViewer.pageControlToolbar)
        }
        if mediaViewer.toolbarHiddenBackup {
            viewsToFadeDuringTransition.append(toolbar)
        }
        for view in viewsToFadeDuringTransition {
            view.alpha = 0
        }
        
        mediaViewer.willStartPushTransition()
        
        // MARK: Animation
        
        // NOTE: Animate only pageControlToolbar with easeInOut curve.
        UIViewPropertyAnimator(duration: 0.25, curve: .easeInOut) {
            mediaViewerView.layoutIfNeeded()
        }.startAnimation()
        
        let duration = transitionDuration(using: transitionContext)
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.7) {
            navigationBar.alpha = navigationBarAlphaBackup
            for view in viewsToFadeDuringTransition {
                view.alpha = 1
            }
            currentPageImageView.frame = currentPageImageFrameInViewer
            currentPageImageView.transitioningConfiguration = configurationBackup
            
            // NOTE: Keep following properties during transition for smooth animation.
            if let sourceView = self.sourceView {
                currentPageImageView.contentMode = sourceView.contentMode
            }
            currentPageImageView.layer.masksToBounds = true
            
            /*
             * [Workaround]
             * If the tabBar becomes hidden and the toolbar remains visible,
             * move it manually because repositioning is not animated.
             */
            if !mediaViewer.toolbarHiddenBackup,
               let tabBar,
               tabBarHiddenBackup! {
                toolbar.frame.origin.y = tabBar.frame.origin.y
            }
        }
        animator.addCompletion { position in
            defer { transitionContext.completeTransition() }
            switch position {
            case .end:
                // Restore properties
                mediaViewer.didFinishPushTransition()
                currentPageImageView.transitioningConfiguration = configurationBackup
                currentPageView.restoreLayoutConfigurationAfterTransition()
                self.sourceView?.isHidden = sourceViewHiddenBackup
                
                if let tabBar {
                    tabBar.isHidden = tabBarHiddenBackup!
                    tabBar.scrollEdgeAppearance = tabBarScrollEdgeAppearanceBackup
                    tabBarSuperviewBackup?.addSubview(tabBar)
                }
            case .start, .current:
                assertionFailure("Unexpected position: \(position)")
            @unknown default:
                assertionFailure("Unknown position: \(position)")
            }
        }
        animator.startAnimation()
    }
    
    private func animatePopTransition(
        using transitionContext: some UIViewControllerContextTransitioning
    ) {
        guard let mediaViewer = transitionContext.viewController(forKey: .from) as? MediaViewerViewController,
              let mediaViewerView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to),
              let toVC = transitionContext.viewController(forKey: .to),
              let navigationController = mediaViewer.navigationController
        else {
            preconditionFailure(
                "\(Self.self) works only with the push/pop animation for \(MediaViewerViewController.self)."
            )
        }
        let containerView = transitionContext.containerView
        containerView.addSubview(toView)
        containerView.addSubview(mediaViewerView)
        
        // Back up
        let sourceViewHiddenBackup = sourceView?.isHidden ?? false
        let toVCToolbarItemsBackup = toVC.toolbarItems
        let toVCAdditionalSafeAreaInsetsBackup = toVC.additionalSafeAreaInsets
        
        // MARK: Prepare for the transition
        
        let toolbar = navigationController.toolbar!
        assert(toolbar.layer.animationKeys() == nil)
        
        // [Workaround] Prevent toVC.toolbarItems from showing up during transition.
        if mediaViewer.toolbarHiddenBackup {
            toVC.toolbarItems = nil
        }
        
        /*
         * [Workaround]
         * Even if toVC hides the toolbar, the bottom of the safe area will
         * shift during the transition as if the toolbar were visible, and
         * the layout will be corrupted.
         * To avoid this, adjust the safe area only during the transition.
         */
        if mediaViewer.toolbarHiddenBackup {
            toVC.additionalSafeAreaInsets.bottom = -toolbar.bounds.height
        }
        
        toView.frame = transitionContext.finalFrame(for: toVC)
        toView.layoutIfNeeded()
        
        let currentPageView = mediaViewer.currentPageViewController.mediaViewerOnePageView
        let currentPageImageView = currentPageView.imageView
        let currentPageImageFrameInViewer = mediaViewerView.convert(
            currentPageImageView.frame,
            from: currentPageImageView.superview
        )
        let sourceFrameInViewer = sourceView.map { sourceView in
            mediaViewerView.convert(
                sourceView.frame,
                from: sourceView.superview
            )
        }
        currentPageView.destroyLayoutConfigurationBeforeTransition()
        currentPageImageView.frame = currentPageImageFrameInViewer
        mediaViewer.insertImageViewForTransition(currentPageImageView)
        sourceView?.isHidden = true
        
        mediaViewer.willStartPopTransition()
        
        var viewsToFadeDuringTransition = mediaViewer.subviewsToFadeDuringTransition
        let tabBar = toVC.tabBarController?.tabBar
        let isTabBarHidden = tabBar?.isHidden ?? true
        if isTabBarHidden {
            if mediaViewer.toolbarHiddenBackup {
                viewsToFadeDuringTransition.append(toolbar)
            }
            viewsToFadeDuringTransition.append(mediaViewer.pageControlToolbar)
        }
        
        // MARK: Animation
        
        // NOTE: Animate only pageControlToolbar with easeInOut curve.
        UIViewPropertyAnimator(duration: 0.25, curve: .easeInOut) {
            mediaViewerView.layoutIfNeeded()
        }.startAnimation()
        
        let duration = transitionDuration(using: transitionContext)
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
            for view in viewsToFadeDuringTransition {
                view.alpha = 0
            }
            if let sourceFrameInViewer {
                currentPageImageView.frame = sourceFrameInViewer
                currentPageImageView.transitioningConfiguration = self.sourceView!.transitioningConfiguration
            } else {
                currentPageImageView.alpha = 0
            }
            currentPageImageView.clipsToBounds = true // TODO: Change according to the source configuration
            
            /*
             * [Workaround]
             * If the tabBar becomes visible and the toolbar remains visible,
             * move it manually because repositioning is not animated.
             */
            if !mediaViewer.toolbarHiddenBackup, let tabBar {
                toolbar.frame.origin.y = tabBar.frame.origin.y - toolbar.bounds.height
            }
        }
        
        // Customize the tabBar animation
        if let tabBar = toVC.tabBarController?.tabBar,
           let animationKeys = tabBar.layer.animationKeys() {
            assert(animationKeys.allSatisfy { $0.starts(with: "position") })
            tabBar.layer.removeAllAnimations()
            
            if toVC.hidesBottomBarWhenPushed {
                // Fade out the tabBar
                animator.addAnimations {
                    tabBar.alpha = 0
                }
                animator.addCompletion { position in
                    if position == .end {
                        tabBar.alpha = 1 // Reset
                    }
                }
            } else {
                // Fade in the tabBar
                tabBar.alpha = 0
                animator.addAnimations {
                    tabBar.alpha = 1
                }
            }
        }
        
        animator.addCompletion { position in
            defer { transitionContext.completeTransition() }
            switch position {
            case .end:
                mediaViewerView.removeFromSuperview()
                
                // Restore properties
                self.sourceView?.isHidden = sourceViewHiddenBackup
                toVC.toolbarItems = toVCToolbarItemsBackup
                toVC.additionalSafeAreaInsets = toVCAdditionalSafeAreaInsetsBackup
                navigationController.isToolbarHidden = mediaViewer.toolbarHiddenBackup
                toolbar.alpha = mediaViewer.toolbarAlphaBackup
                
                // Disable the default animation applied to the toolbar
                if let animationKeys = toolbar.layer.animationKeys() {
                    assert(animationKeys.allSatisfy {
                        $0.starts(with: "position")
                        || $0.starts(with: "bounds.size")
                    })
                    toolbar.layer.removeAllAnimations()
                }
            case .start, .current:
                assertionFailure("Unexpected position: \(position)")
            @unknown default:
                assertionFailure("Unknown position: \(position)")
            }
        }
        animator.startAnimation()
    }
}
