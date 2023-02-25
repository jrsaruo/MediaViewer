//
//  ImageViewerOnePageViewController.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit
import Combine

public protocol ImageViewerDataSource: AnyObject {
    func sourceThumbnailView(for imageViewer: ImageViewerOnePageViewController) -> UIImageView?
}

/// An image viewer.
///
/// It is recommended to set your `ImageViewerOnePageViewController` instance to `navigationController?.delegate` to enable smooth transition animation.
/// ```swift
/// let imageViewer = ImageViewerOnePageViewController(image: imageToView)
/// imageViewer.dataSource = self
/// navigationController?.delegate = imageViewer
/// navigationController?.pushViewController(imageViewer, animated: true)
/// ```
///
/// - Note: `ImageViewerOnePageViewController` must be used in `UINavigationController`.
open class ImageViewerOnePageViewController: UIViewController {
    
    private var cancellables: Set<AnyCancellable> = []
    
    /// The data source of the image viewer object.
    open weak var dataSource: (any ImageViewerDataSource)?
    
    let imageViewerOnePageView: ImageViewerOnePageView
    private let imageViewerOnePageVM = ImageViewerOnePageViewModel()
    
    private var interactivePopTransition: ImageViewerInteractivePopTransition?
    
    // MARK: - Initializers
    
    /// Creates a new viewer.
    /// - Parameter image: The image you want to view.
    public init(image: UIImage) {
        self.imageViewerOnePageView = ImageViewerOnePageView(image: image)
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable, message: "init(coder:) is not supported.")
    required public init?(coder: NSCoder) {
        guard let onePageView = ImageViewerOnePageView(coder: coder) else { return nil }
        self.imageViewerOnePageView = onePageView
        super.init(coder: coder)
    }
    
    // MARK: - Override
    
    open override var prefersStatusBarHidden: Bool {
        true
    }
    
    // MARK: - Lifecycle
    
    open override func loadView() {
        view = imageViewerOnePageView
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpViews()
        setUpSubscriptions()
    }
    
    private func setUpViews() {
        // Subviews
        imageViewerOnePageView.singleTapRecognizer.addTarget(self, action: #selector(backgroundTapped))
        imageViewerOnePageView.panRecognizer.addTarget(self, action: #selector(panned))
    }
    
    private func setUpSubscriptions() {
        imageViewerOnePageVM.$showsImageOnly
            .sink { [weak self] showsImageOnly in
                guard let self else { return }
                let animator = UIViewPropertyAnimator(duration: UINavigationController.hideShowBarDuration,
                                                      dampingRatio: 1) {
                    self.navigationController?.navigationBar.alpha = showsImageOnly ? 0 : 1
                    self.view.backgroundColor = showsImageOnly ? .black : .systemBackground
                }
                if showsImageOnly {
                    animator.addCompletion { position in
                        if position == .end {
                            self.navigationController?.isNavigationBarHidden = true
                        }
                    }
                } else {
                    self.navigationController?.isNavigationBarHidden = false
                }
                animator.startAnimation()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    @objc
    private func backgroundTapped(recognizer: UITapGestureRecognizer) {
        imageViewerOnePageVM.showsImageOnly.toggle()
    }
    
    @objc
    private func panned(recognizer: UIPanGestureRecognizer) {
        // Check whether to transition interactively
        guard let sourceThumbnailView = dataSource?.sourceThumbnailView(for: self) else { return }
        
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

// MARK: - UINavigationControllerDelegate -

extension ImageViewerOnePageViewController: UINavigationControllerDelegate {
    
    public func navigationController(_ navigationController: UINavigationController,
                                     animationControllerFor operation: UINavigationController.Operation,
                                     from fromVC: UIViewController,
                                     to toVC: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
        guard let sourceThumbnailView = dataSource?.sourceThumbnailView(for: self) else { return nil }
        return ImageViewerTransition(operation: operation, sourceThumbnailView: sourceThumbnailView)
    }
    
    public func navigationController(_ navigationController: UINavigationController,
                                     interactionControllerFor animationController: any UIViewControllerAnimatedTransitioning) -> (any UIViewControllerInteractiveTransitioning)? {
        return interactivePopTransition
    }
}
