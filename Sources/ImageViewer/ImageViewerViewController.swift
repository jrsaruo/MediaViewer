//
//  ImageViewerViewController.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/25.
//

import UIKit
import Combine

public protocol ImageViewerDataSource: AnyObject {
    func images(in imageViewer: ImageViewerViewController) -> [UIImage]
    func sourceThumbnailView(for imageViewer: ImageViewerViewController) -> UIImageView?
}

/// An image viewer.
///
/// It is recommended to set your `ImageViewerViewController` instance to `navigationController?.delegate` to enable smooth transition animation.
/// ```swift
/// let imageViewer = ImageViewerViewController(image: imageToView)
/// imageViewer.imageViewerDataSource = self
/// navigationController?.delegate = imageViewer
/// navigationController?.pushViewController(imageViewer, animated: true)
/// ```
///
/// - Note: `ImageViewerViewController` must be used in `UINavigationController`. It is NOT allowed to change `dataSource` and `delegate` properties of ``UIPageViewController``.
open class ImageViewerViewController: UIPageViewController {
    
    private var cancellables: Set<AnyCancellable> = []
    
    /// The data source of the image viewer object.
    open weak var imageViewerDataSource: (any ImageViewerDataSource)?
    
    public var currentPage: Int {
        currentPageViewController.page
    }
    
    var currentPageViewController: ImageViewerOnePageViewController {
        guard let imageViewerOnePage = viewControllers?.first as? ImageViewerOnePageViewController else {
            preconditionFailure("\(Self.self) must have only one \(ImageViewerOnePageViewController.self).")
        }
        return imageViewerOnePage
    }
    
    private let imageViewerVM = ImageViewerViewModel()
    
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
    
    /// Creates a new viewer.
    /// - Parameters:
    ///   - image: The image you want to view.
    ///   - page: The page number of the image.
    public init(image: UIImage, page: Int) {
        super.init(transitionStyle: .scroll,
                   navigationOrientation: .horizontal,
                   options: [
                    .interPageSpacing: 16,
                    .spineLocation: SpineLocation.none.rawValue
                   ])
        let imageViewer = ImageViewerOnePageViewController(image: image, page: page)
        setViewControllers([imageViewer], direction: .forward, animated: false)
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Lifecycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        dataSource = self
        delegate = self
        
        guard let navigationController else {
            preconditionFailure("\(Self.self) must be embedded in UINavigationController.")
        }
        
        navigationBarScrollEdgeAppearanceBackup = navigationController.navigationBar.scrollEdgeAppearance
        navigationBarHiddenBackup = navigationController.isNavigationBarHidden
        
        setUpGestureRecognizers()
        setUpSubscriptions()
    }
    
    private func setUpGestureRecognizers() {
        singleTapRecognizer.addTarget(self, action: #selector(backgroundTapped))
        view.addGestureRecognizer(singleTapRecognizer)
        
        panRecognizer.addTarget(self, action: #selector(panned))
        view.addGestureRecognizer(panRecognizer)
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
    
    // MARK: - Override
    
    open override var prefersStatusBarHidden: Bool {
        true
    }
    
    open override func setViewControllers(_ viewControllers: [UIViewController]?,
                                          direction: UIPageViewController.NavigationDirection,
                                          animated: Bool,
                                          completion: ((Bool) -> Void)? = nil) {
        super.setViewControllers(viewControllers,
                                 direction: direction,
                                 animated: animated,
                                 completion: completion)
        pageDidChange()
    }
    
    // MARK: - Methods
    
    private func pageDidChange() {
        singleTapRecognizer.require(toFail: currentPageViewController.imageDoubleTapRecognizer)
    }
    
    // MARK: - Actions
    
    @objc
    private func backgroundTapped(recognizer: UITapGestureRecognizer) {
        imageViewerVM.showsImageOnly.toggle()
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

extension ImageViewerViewController: UIPageViewControllerDataSource {
    
    public func presentationCount(for pageViewController: UIPageViewController) -> Int {
        guard let images = imageViewerDataSource?.images(in: self) else { return 0 }
        return images.count
    }
    
    public func pageViewController(_ pageViewController: UIPageViewController,
                                   viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let images = imageViewerDataSource?.images(in: self) else { return nil }
        guard let imageViewerPageVC = viewController as? ImageViewerOnePageViewController else {
            assertionFailure("Unknown view controller: \(viewController)")
            return nil
        }
        let previousPage = imageViewerPageVC.page - 1
        guard images.indices.contains(previousPage) else { return nil }
        return ImageViewerOnePageViewController(image: images[previousPage], page: previousPage)
    }
    
    public func pageViewController(_ pageViewController: UIPageViewController,
                                   viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let images = imageViewerDataSource?.images(in: self) else { return nil }
        guard let imageViewerPageVC = viewController as? ImageViewerOnePageViewController else {
            assertionFailure("Unknown view controller: \(viewController)")
            return nil
        }
        let nextPage = imageViewerPageVC.page + 1
        guard images.indices.contains(nextPage) else { return nil }
        return ImageViewerOnePageViewController(image: images[nextPage], page: nextPage)
    }
}

// MARK: - UIPageViewControllerDelegate -

extension ImageViewerViewController: UIPageViewControllerDelegate {
    
    public func pageViewController(_ pageViewController: UIPageViewController,
                                   didFinishAnimating finished: Bool,
                                   previousViewControllers: [UIViewController],
                                   transitionCompleted completed: Bool) {
        if completed {
            pageDidChange()
        }
    }
}

// MARK: - UINavigationControllerDelegate -

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
