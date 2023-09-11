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
               provider: @Sendable () async -> UIImage?)
    
    /// An image source that represents the lack of an image.
    ///
    /// This is equivalent to `.sync(nil)`.
    static var none: Self { .sync(nil) }
}

// MARK: - ImageViewerDataSource -

/// The object you use to provide data for an image viewer.
@MainActor
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
                     imageSourceOnPage page: Int) -> ImageSource
    
    /// Asks the data source to return an aspect ratio of image.
    ///
    /// The ratio will be used to determine a size of page thumbnail.
    /// This method should return immediately.
    ///
    /// - Parameters:
    ///   - imageViewer: An object representing the image viewer requesting this information.
    ///   - page: A page in the image viewer.
    /// - Returns: An aspect ratio of image on the specified page.
    func imageViewer(_ imageViewer: ImageViewerViewController,
                     imageWidthToHeightOnPage page: Int) -> CGFloat?
    
    /// Asks the data source to return a source of a thumbnail image on the page control bar in the image viewer.
    /// - Parameters:
    ///   - imageViewer: An object representing the image viewer requesting this information.
    ///   - page: A page in the image viewer.
    ///   - preferredThumbnailSize: An expected size of the thumbnail image. For better performance, it is preferable to shrink the thumbnail image to a size that fills this size.
    /// - Returns: A source of a thumbnail image on the page control bar in `imageViewer`.
    func imageViewer(_ imageViewer: ImageViewerViewController,
                     pageThumbnailOnPage page: Int,
                     filling preferredThumbnailSize: CGSize) -> ImageSource
    
    /// Asks the data source to return the transition source image view for the current page of the image viewer.
    ///
    /// The image viewer uses this view for push or pop transitions.
    /// On the push transition, an animation runs as the image expands from this view. The reverse happens on the pop.
    ///
    /// If `nil`, the animation looks like cross-dissolve.
    ///
    /// - Parameter imageViewer: An object representing the image viewer requesting this information.
    /// - Returns: The transition source view for current page of `imageViewer`.
    func transitionSourceView(forCurrentPageOf imageViewer: ImageViewerViewController) -> UIImageView?
}

extension ImageViewerDataSource {
    
    public func imageViewer(_ imageViewer: ImageViewerViewController,
                            imageWidthToHeightOnPage page: Int) -> CGFloat? {
        let imageSource = self.imageViewer(imageViewer, imageSourceOnPage: page)
        switch imageSource {
        case .sync(let image?) where image.size.height > 0:
            return image.size.width / image.size.height
        case .sync, .async:
            return nil
        }
    }
    
    public func imageViewer(_ imageViewer: ImageViewerViewController,
                            pageThumbnailOnPage page: Int,
                            filling preferredThumbnailSize: CGSize) -> ImageSource {
        switch self.imageViewer(imageViewer, imageSourceOnPage: page) {
        case .sync(let image):
            return .sync(image?.preparingThumbnail(of: preferredThumbnailSize) ?? image)
        case .async(let transition, let imageProvider):
            return .async(transition: transition) {
                let image = await imageProvider()
                return await image?.byPreparingThumbnail(ofSize: preferredThumbnailSize) ?? image
            }
        }
    }
}

// MARK: - ImageViewerDelegate -

@MainActor
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
    
    private lazy var scrollView = view.firstSubview(ofType: UIScrollView.self)!
    
    // NOTE: This is required for transition.
    private let backgroundView = UIView()
    
    // NOTE: Specify a dummy frame as a workaround to avoid AutoLayout warnings.
    public let toolbar = UIToolbar(frame: .init(x: 0, y: 0, width: 300, height: 44))
    
    private let pageControlToolbar = UIToolbar()
    private let pageControlBar = ImageViewerPageControlBar()
    
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
        
        hidesBottomBarWhenPushed = true
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
        view.insertSubview(backgroundView, at: 0)
        view.addSubview(toolbar)
        view.addSubview(pageControlToolbar)
        
        if let imageViewerDataSource {
            let numberOfPages = imageViewerDataSource.numberOfImages(in: self)
            pageControlBar.configure(numberOfPages: numberOfPages, currentPage: currentPage)
        }
        pageControlToolbar.addSubview(pageControlBar)
        
        // Layout
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        pageControlToolbar.translatesAutoresizingMaskIntoConstraints = false
        pageControlBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            pageControlToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageControlToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageControlToolbar.bottomAnchor.constraint(equalTo: toolbar.topAnchor),
            
            pageControlBar.topAnchor.constraint(equalTo: pageControlToolbar.topAnchor, constant: 1),
            pageControlBar.leadingAnchor.constraint(equalTo: pageControlToolbar.leadingAnchor),
            pageControlBar.trailingAnchor.constraint(equalTo: pageControlToolbar.trailingAnchor),
            pageControlBar.bottomAnchor.constraint(equalTo: pageControlToolbar.bottomAnchor, constant: -1),
        ])
    }
    
    private func setUpGestureRecognizers() {
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
                    self.backgroundView.backgroundColor = showsImageOnly ? .black : .systemBackground
                    self.toolbar.isHidden = showsImageOnly
                    self.pageControlToolbar.isHidden = showsImageOnly
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
        
        pageControlBar.pageDidChange
            .sink { [weak self] page, reason in
                switch reason {
                case .tapOnPageThumbnail, .scrollingBar:
                    self?.move(toPage: page, animated: false)
                case .configuration, .interactivePaging:
                    // Do nothing because it has already been moved to the page.
                    break
                }
            }
            .store(in: &cancellables)
        
        scrollView.publisher(for: \.contentOffset)
            .removeDuplicates()
            .dropFirst(2) // Useless changes
            .sink { [weak self] _ in
                self?.handleContentOffsetChange()
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
        imageViewerDelegate?.imageViewer(self, didMoveTo: currentPage)
    }
    
    private func handleContentOffsetChange() {
        // Update layout of the page control bar interactively.
        let progress0To2 = scrollView.contentOffset.x / scrollView.bounds.width
        let isMovingToNextPage = progress0To2 > 1
        let rawProgress = isMovingToNextPage ? (progress0To2 - 1) : (1 - progress0To2)
        let progress = min(max(rawProgress, 0), 1)
        
        switch pageControlBar.state {
        case .transitioningInteractively(_, let forwards):
            if progress == 1 {
                pageControlBar.finishInteractivePaging()
            } else if forwards == isMovingToNextPage {
                pageControlBar.updatePagingProgress(progress)
            } else {
                pageControlBar.cancelInteractivePaging()
            }
        case .collapsing, .collapsed, .expanding, .expanded:
            // Prevent start when paging is finished and progress is reset to 0.
            if progress != 0 {
                pageControlBar.startInteractivePaging(forwards: isMovingToNextPage)
            }
        }
    }
    
    /// Insert an animated image view for the transition.
    /// - Parameter animatedImageView: An animated image view during the transition.
    func insertImageViewForTransition(_ animatedImageView: UIImageView) {
        view.insertSubview(animatedImageView, belowSubview: toolbar)
    }
    
    // MARK: - Actions
    
    @objc
    private func panned(recognizer: UIPanGestureRecognizer) {
        // Check whether to transition interactively
        let sourceImageView = imageViewerDataSource?.transitionSourceView(forCurrentPageOf: self)
        
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
    
    func imageViewerPageTapped(_ imageViewerPage: ImageViewerOnePageViewController) {
        imageViewerVM.showsImageOnly.toggle()
    }
    
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
        let imageSource = imageViewerDataSource.imageViewer(self, imageSourceOnPage: page)
        
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
                                   thumbnailOnPage page: Int,
                                   filling preferredThumbnailSize: CGSize) -> ImageSource {
        guard let imageViewerDataSource else { return .none }
        return imageViewerDataSource.imageViewer(self,
                                                 pageThumbnailOnPage: page,
                                                 filling: preferredThumbnailSize)
    }
    
    func imageViewerPageControlBar(_ pageControlBar: ImageViewerPageControlBar,
                                   imageWidthToHeightOnPage page: Int) -> CGFloat? {
        imageViewerDataSource?.imageViewer(self, imageWidthToHeightOnPage: page)
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
        let sourceImageView = imageViewerDataSource?.transitionSourceView(forCurrentPageOf: self)
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
        case let pagingRecognizer as UIPanGestureRecognizer
            where pagingRecognizer.view is UIScrollView:
            switch pagingRecognizer.view?.superview {
            case view:
                // Prefer an interactive pop over paging.
                if isMovingDown {
                    // Make paging fail
                    pagingRecognizer.state = .failed
                    return true
                }
            case is ImageViewerOnePageView, is ImageViewerPageControlBar:
                return false
            default:
                assertionFailure("Unknown pan gesture recognizer: \(otherGestureRecognizer)")
            }
        default:
            break
        }
        return false
    }
}
