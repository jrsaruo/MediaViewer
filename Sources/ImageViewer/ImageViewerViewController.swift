//
//  ImageViewerViewController.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/25.
//

import UIKit
import Combine

/// The way to animate the image transition.
public enum ImageTransition: Hashable, Sendable {
    
    /// The fade animation with the specified duration.
    case fade(duration: TimeInterval)
    
    /// No animation.
    case none
}

/// The image source for the image viewer.
public enum ImageSource {
    
    /// An image that can be acquired synchronously.
    case sync(UIImage?)
    
    /// An image that can be acquired asynchronously.
    ///
    /// The viewer will use `provider` to acquire an image and display it using `transition`.
    case async(transition: ImageTransition = .fade(duration: 0.2),
               provider: () async -> UIImage?)
    
    /// An image source that represents the lack of an image.
    ///
    /// This is equivalent to `.sync(nil)`.
    static var none: Self { .sync(nil) }
}

// MARK: - ImageViewerDataSource -

/// The object you use to provide data for an image viewer.
public protocol ImageViewerDataSource: AnyObject {
    
    /// Asks the data source to return the number of images in the image viewer.
    /// - Parameter imageViewer: An object representing the image viewer requesting this information.
    /// - Returns: The number of images in `imageViewer`.
    func numberOfImages(in imageViewer: ImageViewerViewController) -> Int
    
    /// Asks the data source to return a source of an image to view at the particular page in the image viewer.
    /// - Parameters:
    ///   - imageViewer: An object representing the image viewer requesting this information.
    ///   - page: A page in the image viewer.
    /// - Returns: A source of an image to view at `page` in `imageViewer`.
    func imageViewer(_ imageViewer: ImageViewerViewController,
                     imageSourceAtPage page: Int) -> ImageSource
    
    /// Asks the data source to return a source of a thumbnail image on the page control bar in the image viewer.
    /// - Parameters:
    ///   - imageViewer: An object representing the image viewer requesting this information.
    ///   - page: A page in the image viewer.
    /// - Returns: A source of a thumbnail image on the page control bar in `imageViewer`.
    func imageViewer(_ imageViewer: ImageViewerViewController,
                     pageThumbnailAtPage page: Int) -> ImageSource
    
    /// Asks the data source to return the transition source image view for the current page of the image viewer.
    ///
    /// The image viewer uses this view for push or pop transitions.
    /// On the push transition, an animation runs as the image expands from this view. The reverse happens on the pop.
    ///
    /// If `nil`, the default animation runs on the transition.
    ///
    /// - Parameter imageViewer: An object representing the image viewer requesting this information.
    /// - Returns: The transition source view for current page of `imageViewer`.
    func transitionSourceView(forCurrentPageOf imageViewer: ImageViewerViewController) -> UIImageView?
}

extension ImageViewerDataSource {
    
    public func imageViewer(_ imageViewer: ImageViewerViewController,
                            pageThumbnailAtPage page: Int) -> ImageSource {
        self.imageViewer(imageViewer, imageSourceAtPage: page)
    }
}

// MARK: - ImageViewerDelegate -

public protocol ImageViewerDelegate: AnyObject {
    
    /// Tells the delegate an image viewer has moved to a particular page.
    /// - Parameters:
    ///   - imageViewer: An image viewer informing the delegate about the page move.
    ///   - page: A destination page.
    func imageViewer(_ imageViewer: ImageViewerViewController, didMoveTo page: Int)
}

extension ImageViewerDelegate {
    public func imageViewer(_ imageViewer: ImageViewerViewController, didMoveTo page: Int) {}
}

// MARK: - ImageViewerViewController -

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
    
    /// The object that acts as the delegate of the image viewer.
    open weak var imageViewerDelegate: (any ImageViewerDelegate)?
    
    /// The current page of the image viewer.
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
    
    private let pageControlBar = ImageViewerPageControlBar()
    
    private let singleTapRecognizer = UITapGestureRecognizer()
    
    private let panRecognizer: UIPanGestureRecognizer = {
        let recognizer = UIPanGestureRecognizer()
        recognizer.maximumNumberOfTouches = 1
        return recognizer
    }()
    
    private var interactivePopTransition: ImageViewerInteractivePopTransition?
    
    private var shouldHideHomeIndicator = false {
        didSet {
            setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
    }
    
    // MARK: Backups
    
    private var navigationBarScrollEdgeAppearanceBackup: UINavigationBarAppearance?
    private var navigationBarHiddenBackup = false
    
    // MARK: - Initializers
    
    /// Creates a new viewer.
    /// - Parameters:
    ///   - page: The page number of the image.
    ///   - dataSource: The data source for the viewer.
    public init(page: Int, dataSource: any ImageViewerDataSource) {
        super.init(transitionStyle: .scroll,
                   navigationOrientation: .horizontal,
                   options: [
                    .interPageSpacing: 40,
                    .spineLocation: SpineLocation.none.rawValue
                   ])
        imageViewerDataSource = dataSource
        
        guard let imageViewerPage = makeImageViewerPage(forPage: page) else {
            preconditionFailure("Page \(page) out of range.")
        }
        setViewControllers([imageViewerPage], direction: .forward, animated: false)
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Lifecycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        dataSource = self
        delegate = self
        pageControlBar.dataSource = self
        pageControlBar.delegate = self
        
        guard let navigationController else {
            preconditionFailure("\(Self.self) must be embedded in UINavigationController.")
        }
        
        navigationBarScrollEdgeAppearanceBackup = navigationController.navigationBar.scrollEdgeAppearance
        navigationBarHiddenBackup = navigationController.isNavigationBarHidden
        
        setUpViews()
        setUpGestureRecognizers()
        setUpSubscriptions()
        
        /*
         * NOTE:
         * This delegate method is also called at initialization time,
         * but since the delegate has not yet been set by the caller,
         * it needs to be told to the caller again at this time.
         */
        imageViewerDelegate?.imageViewer(self, didMoveTo: currentPage)
    }
    
    private func setUpViews() {
        // Subviews
        if let imageViewerDataSource {
            let numberOfPages = imageViewerDataSource.numberOfImages(in: self)
            pageControlBar.configure(numberOfPages: numberOfPages)
        }
        view.addSubview(pageControlBar)
        
        // Layout
        pageControlBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageControlBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageControlBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageControlBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func setUpGestureRecognizers() {
        singleTapRecognizer.addTarget(self, action: #selector(backgroundTapped))
        view.addGestureRecognizer(singleTapRecognizer)
        
        panRecognizer.delegate = self
        panRecognizer.addTarget(self, action: #selector(panned))
        view.addGestureRecognizer(panRecognizer)
    }
    
    private func setUpSubscriptions() {
        imageViewerVM.$showsImageOnly
            .sink { [weak self] showsImageOnly in
                guard let self else { return }
                self.shouldHideHomeIndicator = showsImageOnly
                
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
    
    open override var prefersHomeIndicatorAutoHidden: Bool {
        shouldHideHomeIndicator
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
    
    /// Move to show an image on the specified page.
    /// - Parameter page: The destination page.
    open func move(toPage page: Int, animated: Bool) {
        guard let imageViewerPage = makeImageViewerPage(forPage: page) else { return }
        setViewControllers([imageViewerPage],
                           direction: page < currentPage ? .reverse : .forward,
                           animated: animated)
    }
    
    private func pageDidChange() {
        singleTapRecognizer.require(toFail: currentPageViewController.imageDoubleTapRecognizer)
        imageViewerDelegate?.imageViewer(self, didMoveTo: currentPage)
    }
    
    // MARK: - Actions
    
    @objc
    private func backgroundTapped(recognizer: UITapGestureRecognizer) {
        imageViewerVM.showsImageOnly.toggle()
    }
    
    @objc
    private func panned(recognizer: UIPanGestureRecognizer) {
        // Check whether to transition interactively
        guard let sourceImageView = imageViewerDataSource?.transitionSourceView(forCurrentPageOf: self) else { return }
        
        if recognizer.state == .began {
            // Start the interactive pop transition
            interactivePopTransition = .init(sourceImageView: sourceImageView)
            navigationController?.popViewController(animated: true)
        }
        
        interactivePopTransition?.panRecognized(by: recognizer, in: self)
        
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

// MARK: - ImageViewerOnePageViewControllerDelegate -

extension ImageViewerViewController: ImageViewerOnePageViewControllerDelegate {
    
    func imageViewerPage(_ imageViewerPage: ImageViewerOnePageViewController,
                         didDoubleTap imageView: UIImageView) {
        imageViewerVM.showsImageOnly = true
    }
}

// MARK: - UIPageViewControllerDataSource -

extension ImageViewerViewController: UIPageViewControllerDataSource {
    
    open func presentationCount(for pageViewController: UIPageViewController) -> Int {
        imageViewerDataSource?.numberOfImages(in: self) ?? 0
    }
    
    open func pageViewController(_ pageViewController: UIPageViewController,
                                 viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let imageViewerPageVC = viewController as? ImageViewerOnePageViewController else {
            assertionFailure("Unknown view controller: \(viewController)")
            return nil
        }
        let previousPage = imageViewerPageVC.page - 1
        if let previousPageVC = makeImageViewerPage(forPage: previousPage) {
            return previousPageVC
        }
        return nil
    }
    
    open func pageViewController(_ pageViewController: UIPageViewController,
                                 viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let imageViewerPageVC = viewController as? ImageViewerOnePageViewController else {
            assertionFailure("Unknown view controller: \(viewController)")
            return nil
        }
        let nextPage = imageViewerPageVC.page + 1
        if let nextPageVC = makeImageViewerPage(forPage: nextPage) {
            return nextPageVC
        }
        return nil
    }
    
    private func makeImageViewerPage(forPage page: Int) -> ImageViewerOnePageViewController? {
        guard let imageViewerDataSource,
              0 <= page,
              page < imageViewerDataSource.numberOfImages(in: self) else { return nil }
        let imageSource = imageViewerDataSource.imageViewer(self, imageSourceAtPage: page)
        
        let imageViewerPage = ImageViewerOnePageViewController(page: page)
        imageViewerPage.delegate = self
        switch imageSource {
        case .sync(let image):
            imageViewerPage.imageViewerOnePageView.setImage(image, with: .none)
        case .async(let transition, let imageProvider):
            Task(priority: .high) {
                let image = await imageProvider()
                imageViewerPage.imageViewerOnePageView.setImage(image, with: transition)
            }
        }
        return imageViewerPage
    }
}

// MARK: - ImageViewerPageControlBarDataSource -

extension ImageViewerViewController: ImageViewerPageControlBarDataSource {
    
    func imageViewerPageControlBar(_ pageControlBar: ImageViewerPageControlBar,
                                   thumbnailOnPage page: Int) -> ImageSource {
        imageViewerDataSource?.imageViewer(self, pageThumbnailAtPage: page) ?? .none
    }
}

// MARK: - ImageViewerPageControlBarDelegate -

extension ImageViewerViewController: ImageViewerPageControlBarDelegate {
    
    func imageViewerPageControlBar(_ pageControlBar: ImageViewerPageControlBar,
                                   didVisitThumbnailOnPage page: Int) {
        move(toPage: page, animated: false)
    }
}

// MARK: - UIPageViewControllerDelegate -

extension ImageViewerViewController: UIPageViewControllerDelegate {
    
    open func pageViewController(_ pageViewController: UIPageViewController,
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
        guard let sourceImageView = imageViewerDataSource?.transitionSourceView(forCurrentPageOf: self) else { return nil }
        return ImageViewerTransition(operation: operation, sourceImageView: sourceImageView)
    }
    
    public func navigationController(_ navigationController: UINavigationController,
                                     interactionControllerFor animationController: any UIViewControllerAnimatedTransitioning) -> (any UIViewControllerInteractiveTransitioning)? {
        return interactivePopTransition
    }
}

// MARK: - UIGestureRecognizerDelegate -

extension ImageViewerViewController: UIGestureRecognizerDelegate {
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Tune gesture recognizers to make it easier to start an interactive pop.
        guard gestureRecognizer == panRecognizer else { return false }
        let velocity = panRecognizer.velocity(in: nil)
        let isMovingDown = velocity.y > 0 && velocity.y > abs(velocity.x)
        
        let imageScrollView = currentPageViewController.imageViewerOnePageView.scrollView
        switch otherGestureRecognizer {
        case imageScrollView.panGestureRecognizer:
            // If the scroll position reaches the top edge, allow an interactive pop by pulldown.
            let isReachingTopEdge = imageScrollView.contentOffset.y <= 0
            if isReachingTopEdge && isMovingDown {
                // Make scrolling fail
                imageScrollView.panGestureRecognizer.state = .failed
                return true
            }
        case let pagingRecognizer as UIPanGestureRecognizer where pagingRecognizer.view is UIScrollView:
            assert(pagingRecognizer.view?.superview == view,
                   "Unknown pan gesture recognizer: \(otherGestureRecognizer)")
            // Prefer an interactive pop over paging.
            if isMovingDown {
                // Make paging fail
                pagingRecognizer.state = .failed
                return true
            }
        default:
            break
        }
        return false
    }
}
