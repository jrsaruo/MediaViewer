//
//  ImageViewerViewController.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit
import Combine

public protocol ImageViewerDataSource: AnyObject {
    func sourceThumbnailView(for imageViewer: ImageViewerViewController) -> UIImageView?
}

/// An image viewer.
///
/// It is recommended to set your `ImageViewerViewController` instance to `navigationController?.delegate` to enable smooth transition animation.
/// ```swift
/// let imageViewer = ImageViewerViewController(image: imageToView)
/// imageViewer.dataSource = self
/// navigationController?.delegate = imageViewer
/// navigationController?.pushViewController(imageViewer, animated: true)
/// ```
///
/// - Note: `ImageViewerViewController` must be used in `UINavigationController`.
open class ImageViewerViewController: UIViewController {
    
    private var cancellables: Set<AnyCancellable> = []
    
    /// The data source of the image viewer object.
    open weak var dataSource: (any ImageViewerDataSource)?
    
    let imageViewerView: ImageViewerView
    private let imageViewerVM = ImageViewerViewModel()
    
    private var interactivePopTransition: ImageViewerInteractivePopTransition?
    
    // MARK: - Backups
    
    private var navigationBarScrollEdgeAppearanceBackup: UINavigationBarAppearance?
    private var navigationBarHiddenBackup = false
    
    // MARK: - Initializers
    
    /// Creates a new viewer.
    /// - Parameter image: The image you want to view.
    public init(image: UIImage) {
        self.imageViewerView = ImageViewerView(image: image)
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable, message: "init(coder:) is not supported.")
    required public init?(coder: NSCoder) {
        guard let imageViewerView = ImageViewerView(coder: coder) else { return nil }
        self.imageViewerView = imageViewerView
        super.init(coder: coder)
    }
    
    // MARK: - Override
    
    open override var prefersStatusBarHidden: Bool {
        true
    }
    
    // MARK: - Lifecycle
    
    open override func loadView() {
        view = imageViewerView
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let navigationController else {
            preconditionFailure("ImageViewerViewController must be embedded in UINavigationController.")
        }
        
        navigationBarScrollEdgeAppearanceBackup = navigationController.navigationBar.scrollEdgeAppearance
        navigationBarHiddenBackup = navigationController.isNavigationBarHidden
        
        setUpViews()
        setUpSubscriptions()
    }
    
    private func setUpViews() {
        // Subviews
        imageViewerView.singleTapRecognizer.addTarget(self, action: #selector(backgroundTapped))
        imageViewerView.panRecognizer.addTarget(self, action: #selector(panned))
    }
    
    private func setUpSubscriptions() {
        imageViewerVM.$showsImageOnly
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
        imageViewerVM.showsImageOnly.toggle()
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

extension ImageViewerViewController: UINavigationControllerDelegate {
    
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
