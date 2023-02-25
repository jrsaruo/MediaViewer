//
//  ImageViewerViewController.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/25.
//

import UIKit

public protocol ImageViewerDataSource: AnyObject {
    func sourceThumbnailView(for imageViewer: ImageViewerViewController) -> UIImageView?
}

open class ImageViewerViewController: UIPageViewController {
    
    /// The data source of the image viewer object.
    open weak var imageViewerDataSource: (any ImageViewerDataSource)?
    
    var currentPageViewController: ImageViewerOnePageViewController {
        guard let imageViewerOnePage = viewControllers?.first as? ImageViewerOnePageViewController else {
            preconditionFailure("\(Self.self) must have only one \(ImageViewerOnePageViewController.self).")
        }
        return imageViewerOnePage
    }
    
    private let singleTapRecognizer = UITapGestureRecognizer()
    
    private let panRecognizer: UIPanGestureRecognizer = {
        let recognizer = UIPanGestureRecognizer()
        recognizer.maximumNumberOfTouches = 1
        return recognizer
    }()
    
    private var interactivePopTransition: ImageViewerInteractivePopTransition?
    
    // MARK: Backups
    
    private var navigationBarScrollEdgeAppearanceBackup: UINavigationBarAppearance?
    private var navigationBarHiddenBackup = false
    
    // MARK: - Initializers
    
    public init(image: UIImage) {
        super.init(transitionStyle: .scroll,
                   navigationOrientation: .horizontal,
                   options: [
                    .interPageSpacing: 16,
                    .spineLocation: SpineLocation.none.rawValue
                   ])
        let imageViewer = ImageViewerOnePageViewController(image: image)
        setViewControllers([imageViewer], direction: .forward, animated: false)
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Lifecycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let navigationController else {
            preconditionFailure("ImageViewerOnePageViewController must be embedded in UINavigationController.")
        }
        
        navigationBarScrollEdgeAppearanceBackup = navigationController.navigationBar.scrollEdgeAppearance
        navigationBarHiddenBackup = navigationController.isNavigationBarHidden
        
        setUpGestureRecognizers()
    }
    
    private func setUpGestureRecognizers() {
        singleTapRecognizer.addTarget(self, action: #selector(backgroundTapped))
        // TODO: Prefer double-tap over single-tap
        view.addGestureRecognizer(singleTapRecognizer)
        
        panRecognizer.addTarget(self, action: #selector(panned))
        view.addGestureRecognizer(panRecognizer)
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        navigationController?.navigationBar.scrollEdgeAppearance = navigationBarScrollEdgeAppearanceBackup
        navigationController?.setNavigationBarHidden(navigationBarHiddenBackup, animated: animated)
    }
    
    // MARK: - Actions
    
    @objc
    private func backgroundTapped(recognizer: UITapGestureRecognizer) {
        // TODO: Toggle the navigation bar visibility
    }
    
    @objc
    private func panned(recognizer: UIPanGestureRecognizer) {
        // Check whether to transition interactively
        guard let sourceThumbnailView = imageViewerDataSource?.sourceThumbnailView(for: self) else { return }
        
        if recognizer.state == .began {
            // Start the interactive pop transition
            interactivePopTransition = .init(sourceThumbnailView: sourceThumbnailView)
            navigationController?.popViewController(animated: true)
        }
        
        interactivePopTransition?.panRecognized(by: recognizer)
        
        switch recognizer.state {
        case .possible, .began, .changed:
            break
        case .ended, .cancelled, .failed:
            interactivePopTransition = nil
        @unknown default:
            assertionFailure("Unknown state: \(recognizer.state)")
            interactivePopTransition = nil
        }
    }
}

extension ImageViewerViewController: UINavigationControllerDelegate {
    
    public func navigationController(_ navigationController: UINavigationController,
                                     animationControllerFor operation: UINavigationController.Operation,
                                     from fromVC: UIViewController,
                                     to toVC: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
        guard let sourceThumbnailView = imageViewerDataSource?.sourceThumbnailView(for: self) else { return nil }
        return ImageViewerTransition(operation: operation, sourceThumbnailView: sourceThumbnailView)
    }
    
    public func navigationController(_ navigationController: UINavigationController,
                                     interactionControllerFor animationController: any UIViewControllerAnimatedTransitioning) -> (any UIViewControllerInteractiveTransitioning)? {
        return interactivePopTransition
    }
}
