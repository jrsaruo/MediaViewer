//
//  MediaViewerViewController.swift
//
//
//  Created by Yusaku Nishi on 2023/02/25.
//

import UIKit
import Combine

/// A type-erased media identifier.
struct AnyMediaIdentifier: Hashable {
    let rawValue: AnyHashable
}

/// An media viewer.
///
/// It is recommended to set your `MediaViewerViewController` instance to `navigationController?.delegate` to enable smooth transition animation.
///
/// ```swift
/// let mediaViewer = MediaViewerViewController(page: 0, dataSource: self)
/// navigationController?.delegate = mediaViewer
/// navigationController?.pushViewController(mediaViewer, animated: true)
/// ```
///
/// You can show toolbar items by setting `toolbarItems` property on the media viewer instance.
///
/// ```swift
/// mediaViewer.toolbarItems = [
///     UIBarButtonItem(...)
/// ]
/// ```
///
/// - Note: `MediaViewerViewController` must be used in `UINavigationController`.
///         It is NOT allowed to change `dataSource` and `delegate` properties of ``UIPageViewController``.
open class MediaViewerViewController: UIPageViewController {
    
    private var cancellables: Set<AnyCancellable> = []
    
    /// The data source of the media viewer object.
    open weak var mediaViewerDataSource: (any MediaViewerDataSource)?
    
    /// The object that acts as the delegate of the media viewer.
    open weak var mediaViewerDelegate: (any MediaViewerDelegate)?
    
    /// The current page of the media viewer.
    public var currentPage: Int {
        mediaViewerVM.page(with: currentMediaIdentifier)!
    }
    
    var currentMediaIdentifier: AnyMediaIdentifier {
        currentPageViewController.mediaIdentifier
    }
    
    var currentPageViewController: MediaViewerOnePageViewController {
        guard let mediaViewerOnePage = viewControllers?.first as? MediaViewerOnePageViewController else {
            preconditionFailure(
                "\(Self.self) must have only one \(MediaViewerOnePageViewController.self)."
            )
        }
        return mediaViewerOnePage
    }
    
    public var isShowingMediaOnly: Bool {
        mediaViewerVM.showsMediaOnly
    }
    
    private let mediaViewerVM = MediaViewerViewModel()
    
    private lazy var scrollView = view.firstSubview(ofType: UIScrollView.self)!
    
    // NOTE: This is required for transition.
    private let backgroundView = UIView()
    
    let pageControlToolbar = UIToolbar()
    private let pageControlBar = MediaViewerPageControlBar()
    
    private let panRecognizer: UIPanGestureRecognizer = {
        let recognizer = UIPanGestureRecognizer()
        recognizer.maximumNumberOfTouches = 1
        return recognizer
    }()
    
    private var interactivePopTransition: MediaViewerInteractivePopTransition?
    
    private var shouldHideHomeIndicator = false {
        didSet {
            setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
    }
    
    // MARK: Layout constraints
    
    private lazy var expandedPageControlToolbarConstraints = [
        pageControlBar.topAnchor.constraint(
            equalTo: pageControlToolbar.topAnchor,
            constant: 1
        ),
        pageControlToolbar.heightAnchor.constraint(
            equalToConstant: pageControlToolbar.systemLayoutSizeFitting(
                UIView.layoutFittingCompressedSize
            ).height
        )
    ]
    
    // NOTE: Activated during the screen transition.
    private lazy var collapsedPageControlToolbarConstraints = [
        pageControlToolbar.heightAnchor.constraint(equalToConstant: 0)
    ]
    
    // MARK: Backups
    
    private(set) var tabBarHiddenBackup: Bool?
    private(set) var navigationBarAlphaBackup = 1.0
    private(set) var navigationBarHiddenBackup = false
    private(set) var toolbarHiddenBackup = true
    private(set) var toolbarScrollEdgeAppearanceBackup: UIToolbarAppearance?
    
    // MARK: - Initializers
    
    /// Creates a new viewer.
    /// - Parameters:
    ///   - page: The page number of the media.
    ///   - dataSource: The data source for the viewer.
    public init(page: Int, dataSource: some MediaViewerDataSource) {
        super.init(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: [
                .interPageSpacing: 40,
                .spineLocation: SpineLocation.none.rawValue
            ]
        )
        mediaViewerDataSource = dataSource
        
        let identifiers = dataSource.mediaIdentifiers(for: self)
        mediaViewerVM.mediaIdentifiers = identifiers.map(AnyMediaIdentifier.init)
        
        guard let identifier = mediaViewerVM.mediaIdentifier(forPage: page),
              let mediaViewerPage = makeMediaViewerPage(with: identifier) else {
            preconditionFailure("Page \(page) out of range.")
        }
        setViewControllers([mediaViewerPage], direction: .forward, animated: false)
        
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
            preconditionFailure(
                "\(Self.self) must be embedded in UINavigationController."
            )
        }
        
        tabBarHiddenBackup = tabBarController?.tabBar.isHidden
        navigationBarAlphaBackup = navigationController.navigationBar.alpha
        navigationBarHiddenBackup = navigationController.isNavigationBarHidden
        toolbarHiddenBackup = navigationController.isToolbarHidden
        
        setUpViews()
        setUpGestureRecognizers()
        setUpSubscriptions()
        
        /*
         * NOTE:
         * This delegate method is also called at initialization time,
         * but since the delegate has not yet been set by the caller,
         * it needs to be told to the caller again at this time.
         */
        mediaViewerDelegate?.mediaViewer(self, didMoveToPage: currentPage)
    }
    
    private func setUpViews() {
        // Navigation
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        navigationItem.scrollEdgeAppearance = appearance
        
        // Subviews
        view.insertSubview(backgroundView, at: 0)
        view.addSubview(pageControlToolbar)
        
        pageControlBar.configure(
            mediaIdentifiers: mediaViewerVM.mediaIdentifiers,
            currentPage: currentPage
        )
        pageControlToolbar.addSubview(pageControlBar)
        
        // Layout
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        pageControlToolbar.translatesAutoresizingMaskIntoConstraints = false
        pageControlBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            pageControlToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageControlToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageControlToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            pageControlBar.leadingAnchor.constraint(equalTo: pageControlToolbar.leadingAnchor),
            pageControlBar.trailingAnchor.constraint(equalTo: pageControlToolbar.trailingAnchor),
            pageControlBar.bottomAnchor.constraint(equalTo: pageControlToolbar.bottomAnchor, constant: -1),
        ] + expandedPageControlToolbarConstraints)
    }
    
    private func setUpGestureRecognizers() {
        panRecognizer.delegate = self
        panRecognizer.addTarget(self, action: #selector(panned))
        view.addGestureRecognizer(panRecognizer)
    }
    
    private func setUpSubscriptions() {
        mediaViewerVM.$showsMediaOnly
            .sink { [weak self] showsMediaOnly in
                guard let self else { return }
                shouldHideHomeIndicator = showsMediaOnly
                
                let animator = UIViewPropertyAnimator(
                    duration: UINavigationController.hideShowBarDuration,
                    dampingRatio: 1
                ) {
                    self.tabBarController?.tabBar.isHidden = showsMediaOnly || self.hidesBottomBarWhenPushed
                    self.navigationController?.navigationBar.alpha = showsMediaOnly ? 0 : 1
                    self.backgroundView.backgroundColor = showsMediaOnly ? .black : .systemBackground
                    self.navigationController?.toolbar.isHidden = showsMediaOnly
                    self.pageControlToolbar.isHidden = showsMediaOnly
                }
                if showsMediaOnly {
                    animator.addCompletion { position in
                        if position == .end {
                            self.navigationController?.isNavigationBarHidden = true
                        }
                    }
                } else {
                    navigationController?.isNavigationBarHidden = false
                }
                
                // Ignore single tap during animation
                let singleTap = currentPageViewController.singleTapRecognizer
                singleTap.isEnabled = false
                animator.addCompletion { _ in
                    singleTap.isEnabled = true
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
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        guard let navigationController else {
            preconditionFailure(
                "\(Self.self) must be embedded in UINavigationController."
            )
        }
        
        // Restore the appearance
        // NOTE: Animating in the transitionCoordinator.animate(...) didn't work.
        let tabBar = tabBarController?.tabBar
        if let tabBar, let tabBarHiddenBackup {
            let tabBarWillAppear = tabBar.isHidden && !tabBarHiddenBackup
            if tabBarWillAppear {
                /*
                 * NOTE:
                 * This animation will be managed by InteractivePopTransition.
                 */
                tabBar.alpha = 0
                UIView.animate(withDuration: 0.2) {
                    tabBar.alpha = 1
                }
            }
            tabBar.isHidden = tabBarHiddenBackup
        }
        navigationController.navigationBar.alpha = navigationBarAlphaBackup
        navigationController.setNavigationBarHidden(
            navigationBarHiddenBackup,
            animated: animated
        )
        
        transitionCoordinator?.animate(alongsideTransition: { _ in }) { context in
            if context.isCancelled {
                // Cancel the appearance restoration
                tabBar?.isHidden = self.isShowingMediaOnly || self.hidesBottomBarWhenPushed
                navigationController.navigationBar.alpha = self.isShowingMediaOnly ? 0 : 1
                navigationController.isNavigationBarHidden = self.isShowingMediaOnly
            }
        }
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // NOTE: navigationController is nil on pop.
        if let navigationController, navigationController.isToolbarHidden {
            navigationController.setToolbarHidden(false, animated: true)
        }
    }
    
    // MARK: - Override
    
    open override var prefersStatusBarHidden: Bool {
        true
    }
    
    open override var prefersHomeIndicatorAutoHidden: Bool {
        shouldHideHomeIndicator
    }
    
    open override func setViewControllers(
        _ viewControllers: [UIViewController]?,
        direction: UIPageViewController.NavigationDirection,
        animated: Bool,
        completion: ((Bool) -> Void)? = nil
    ) {
        super.setViewControllers(
            viewControllers,
            direction: direction,
            animated: animated,
            completion: completion
        )
        pageDidChange()
    }
    
    // MARK: - Methods
    
    /// Move to show media on the specified page.
    /// - Parameter page: The destination page.
    open func move(toPage page: Int, animated: Bool) {
        guard let identifier = mediaViewerVM.mediaIdentifier(forPage: page) else {
            preconditionFailure("Page \(page) out of range.")
        }
        guard let mediaViewerPage = makeMediaViewerPage(with: identifier) else { return }
        setViewControllers(
            [mediaViewerPage],
            direction: page < currentPage ? .reverse : .forward,
            animated: animated
        )
    }
    
    private func pageDidChange() {
        mediaViewerDelegate?.mediaViewer(self, didMoveToPage: currentPage)
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
    
    // MARK: - Actions
    
    @objc
    private func panned(recognizer: UIPanGestureRecognizer) {
        if recognizer.state == .began {
            // Start the interactive pop transition
            let sourceView = mediaViewerDataSource?.mediaViewer(
                self,
                transitionSourceViewForMediaWith: currentMediaIdentifier
            )
            interactivePopTransition = .init(sourceView: sourceView)
            
            /*
             * [Workaround]
             * If the recognizer detects a gesture while the main thread is blocked,
             * the interactive transition will not work properly.
             * By delaying popViewController with Task, recognizer.state becomes
             * `.ended` first and interactivePopTransition becomes nil,
             * so a normal transition runs and avoids that problem.
             *
             * However, it leads to another glitch:
             * later interactivePopTransition.panRecognized(by:in:) changes
             * the anchor point of the image view while it is still on the
             * scroll view, causing the image view to be shifted.
             * To avoid it, call prepareForInteractiveTransition(for:) and
             * remove the image view from the scroll view in advance.
             */
            interactivePopTransition?.prepareForInteractiveTransition(for: self)
            Task {
                navigationController?.popViewController(animated: true)
            }
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

// MARK: - MediaViewerOnePageViewControllerDelegate -

extension MediaViewerViewController: MediaViewerOnePageViewControllerDelegate {
    
    func mediaViewerPageTapped(_ mediaViewerPage: MediaViewerOnePageViewController) {
        mediaViewerVM.showsMediaOnly.toggle()
    }
    
    func mediaViewerPage(
        _ mediaViewerPage: MediaViewerOnePageViewController,
        didDoubleTap imageView: UIImageView
    ) {
        mediaViewerVM.showsMediaOnly = true
    }
}

// MARK: - UIPageViewControllerDataSource -

extension MediaViewerViewController: UIPageViewControllerDataSource {
    
    open func presentationCount(for pageViewController: UIPageViewController) -> Int {
        mediaViewerVM.mediaIdentifiers.count
    }
    
    open func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let mediaViewerPageVC = viewController as? MediaViewerOnePageViewController else {
            assertionFailure("Unknown view controller: \(viewController)")
            return nil
        }
        guard let previousIdentifier = mediaViewerVM.mediaIdentifier(before: mediaViewerPageVC.mediaIdentifier) else {
            return nil
        }
        return makeMediaViewerPage(with: previousIdentifier)
    }
    
    open func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let mediaViewerPageVC = viewController as? MediaViewerOnePageViewController else {
            assertionFailure("Unknown view controller: \(viewController)")
            return nil
        }
        guard let nextIdentifier = mediaViewerVM.mediaIdentifier(after: mediaViewerPageVC.mediaIdentifier) else {
            return nil
        }
        return makeMediaViewerPage(with: nextIdentifier)
    }
    
    private func makeMediaViewerPage(
        with identifier: AnyMediaIdentifier
    ) -> MediaViewerOnePageViewController? {
        guard let mediaViewerDataSource else { return nil }
        let media = mediaViewerDataSource.mediaViewer(self, mediaWith: identifier)
        
        let mediaViewerPage = MediaViewerOnePageViewController(
            mediaIdentifier: identifier
        )
        mediaViewerPage.delegate = self
        switch media {
        case .image(.sync(let image)):
            mediaViewerPage.mediaViewerOnePageView.setImage(image, with: .none)
        case .image(.async(let transition, let imageProvider)):
            Task(priority: .high) {
                let image = await imageProvider()
                mediaViewerPage.mediaViewerOnePageView.setImage(image, with: transition)
            }
        }
        return mediaViewerPage
    }
}

// MARK: - MediaViewerPageControlBarDataSource -

extension MediaViewerViewController: MediaViewerPageControlBarDataSource {
    
    func mediaViewerPageControlBar(
        _ pageControlBar: MediaViewerPageControlBar,
        thumbnailWith mediaIdentifier: AnyMediaIdentifier,
        filling preferredThumbnailSize: CGSize
    ) -> Source<UIImage?> {
        guard let mediaViewerDataSource else { return .none }
        return mediaViewerDataSource.mediaViewer(
            self,
            pageThumbnailForMediaWith: mediaIdentifier,
            filling: preferredThumbnailSize
        )
    }
    
    func mediaViewerPageControlBar(
        _ pageControlBar: MediaViewerPageControlBar,
        widthToHeightOfThumbnailWith mediaIdentifier: AnyMediaIdentifier
    ) -> CGFloat? {
        mediaViewerDataSource?.mediaViewer(
            self,
            widthToHeightOfMediaWith: mediaIdentifier
        )
    }
}

// MARK: - UIPageViewControllerDelegate -

extension MediaViewerViewController: UIPageViewControllerDelegate {
    
    open func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        if completed {
            pageDidChange()
        }
    }
}

// MARK: - UINavigationControllerDelegate -

extension MediaViewerViewController: UINavigationControllerDelegate {
    
    public func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        if operation == .pop && fromVC == self {
            mediaViewerDelegate?.mediaViewer(
                self,
                willBeginPopTransitionTo: toVC
            )
        }
        let sourceView = interactivePopTransition?.sourceView ?? mediaViewerDataSource?.mediaViewer(
            self,
            transitionSourceViewForMediaWith: currentMediaIdentifier
        )
        return MediaViewerTransition(
            operation: operation,
            sourceView: sourceView,
            sourceImage: { [weak self] in
                guard let self else { return nil }
                return mediaViewerDataSource?.mediaViewer(
                    self,
                    transitionSourceImageWith: sourceView
                )
            }
        )
    }
    
    public func navigationController(
        _ navigationController: UINavigationController,
        interactionControllerFor animationController: any UIViewControllerAnimatedTransitioning
    ) -> (any UIViewControllerInteractiveTransitioning)? {
        interactivePopTransition
    }
}

// MARK: - UIGestureRecognizerDelegate -

extension MediaViewerViewController: UIGestureRecognizerDelegate {
    
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Tune gesture recognizers to make it easier to start an interactive pop.
        guard gestureRecognizer == panRecognizer else { return false }
        let velocity = panRecognizer.velocity(in: nil)
        let isMovingDown = velocity.y > 0 && velocity.y > abs(velocity.x)
        
        let mediaScrollView = currentPageViewController.mediaViewerOnePageView.scrollView
        switch otherGestureRecognizer {
        case mediaScrollView.panGestureRecognizer:
            // If the scroll position reaches the top edge, allow an interactive pop by pulldown.
            let isReachingTopEdge = mediaScrollView.contentOffset.y <= 0
            if isReachingTopEdge && isMovingDown {
                // Make scrolling fail
                mediaScrollView.panGestureRecognizer.state = .failed
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
            case is MediaViewerOnePageView, is MediaViewerPageControlBar:
                return false
            default:
                assertionFailure(
                    "Unknown pan gesture recognizer: \(otherGestureRecognizer)"
                )
            }
        default:
            break
        }
        return false
    }
}

// MARK: - Transition helpers -

extension MediaViewerViewController {
    
    var subviewsToFadeDuringTransition: [UIView] {
        view.subviews
            .filter {
                $0 != pageControlToolbar
                && $0 != currentPageViewController.mediaViewerOnePageView.imageView
            }
        + [pageControlBar]
    }
    
    /// Insert an animated image view for the transition.
    /// - Parameter animatedImageView: An animated image view during the transition.
    func insertImageViewForTransition(_ animatedImageView: UIImageView) {
        view.insertSubview(animatedImageView, belowSubview: pageControlToolbar)
    }
    
    private func prepareToolbarsForTransition() {
        // Clip pageControlBar
        pageControlToolbar.clipsToBounds = true
        
        /*
         * [Workaround]
         * When pageControlToolbar.clipsToBounds is true,
         * toolbar becomes transparent so prevent it.
         */
        let toolbar = navigationController!.toolbar!
        toolbarScrollEdgeAppearanceBackup = toolbar.scrollEdgeAppearance
        let appearance = UIToolbarAppearance()
        appearance.configureWithDefaultBackground()
        toolbar.scrollEdgeAppearance = appearance
    }
    
    // MARK: Push transition
    
    func willStartPushTransition() {
        prepareToolbarsForTransition()
        
        NSLayoutConstraint.deactivate(expandedPageControlToolbarConstraints)
        NSLayoutConstraint.activate(collapsedPageControlToolbarConstraints)
        view.layoutIfNeeded()
        NSLayoutConstraint.deactivate(collapsedPageControlToolbarConstraints)
        NSLayoutConstraint.activate(expandedPageControlToolbarConstraints)
    }
    
    func didFinishPushTransition() {
        pageControlToolbar.clipsToBounds = false
        navigationController!.toolbar.scrollEdgeAppearance = toolbarScrollEdgeAppearanceBackup
    }
    
    // MARK: Pop transition
    
    func willStartPopTransition() {
        prepareToolbarsForTransition()
        
        NSLayoutConstraint.deactivate(expandedPageControlToolbarConstraints)
        NSLayoutConstraint.activate(collapsedPageControlToolbarConstraints)
    }
    
    // MARK: Interactive pop transition
    
    func willStartInteractivePopTransition() {
        prepareToolbarsForTransition()
        NSLayoutConstraint.deactivate(expandedPageControlToolbarConstraints)
    }
    
    func didCancelInteractivePopTransition() {
        pageControlToolbar.clipsToBounds = false
        /*
         * NOTE:
         * Restore toolbar.scrollEdgeAppearance in MediaViewerInteractivePopTransition
         * because navigationController has become nil.
         */
        
        NSLayoutConstraint.activate(expandedPageControlToolbarConstraints)
    }
}
