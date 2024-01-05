//
//  MediaViewerViewController.swift
//
//
//  Created by Yusaku Nishi on 2023/02/25.
//

import UIKit
import Combine

/// An media viewer.
///
/// It is recommended to set your `MediaViewerViewController` instance to
/// `navigationController?.delegate` to enable smooth transition animation.
///
/// ```swift
/// let mediaViewer = MediaViewerViewController(opening: 0, dataSource: self)
/// navigationController?.delegate = mediaViewer
/// navigationController?.pushViewController(mediaViewer, animated: true)
/// ```
///
/// To show toolbar items in the media viewer, use `toolbarItems` property on the viewer instance.
///
/// ```swift
/// mediaViewer.toolbarItems = [
///     UIBarButtonItem(...)
/// ]
/// ```
///
/// You can subclass `MediaViewerViewController` and customize it.
///
/// - Note: `MediaViewerViewController` must be embedded in
///         `UINavigationController`.
/// - Note: It is NOT allowed to change `dataSource` and `delegate` properties
///         of ``UIPageViewController``.
open class MediaViewerViewController: UIPageViewController {
    
    private var cancellables: Set<AnyCancellable> = []
    
    /// The data source of the media viewer object.
    ///
    /// - Note: This data source object must be set at object creation time and may not be changed.
    open private(set) weak var mediaViewerDataSource: (any MediaViewerDataSource)!
    
    /// The object that acts as the delegate of the media viewer.
    ///
    /// - Precondition: The associated type `MediaIdentifier` must be the same as
    ///                 the one of `mediaViewerDataSource`.
    open weak var mediaViewerDelegate: (any MediaViewerDelegate)? {
        willSet {
            guard let mediaViewerDataSource else { return }
            newValue?.verifyMediaIdentifierTypeIsSame(as: mediaViewerDataSource)
        }
    }
    
    /// The current page of the media viewer.
    @available(*, deprecated)
    public var currentPage: Int {
        mediaViewerVM.page(with: currentMediaIdentifier)!
    }
    
    /// Returns the identifier for currently viewing media in the viewer.
    /// - Parameter identifierType: A type of the identifier for media.
    ///                             It must match the one provided by `mediaViewerDataSource`.
    public func currentMediaIdentifier<MediaIdentifier>(
        as identifierType: MediaIdentifier.Type = MediaIdentifier.self
    ) -> MediaIdentifier {
        currentMediaIdentifier.as(MediaIdentifier.self)
    }
    
    var currentMediaIdentifier: AnyMediaIdentifier {
        currentPageViewController.mediaIdentifier
    }
    
    /// A view controller for the current page.
    ///
    /// During reloading, `visiblePageViewController` returns the page that was displayed
    /// just before reloading, while `currentPageViewController` returns the page that will be
    /// displayed eventually.
    var currentPageViewController: MediaViewerOnePageViewController {
        if let destinationPageVCAfterReloading {
            return destinationPageVCAfterReloading
        }
        return visiblePageViewController
    }
    
    /// A view controller for the currently visible page.
    var visiblePageViewController: MediaViewerOnePageViewController {
        guard let mediaViewerOnePage = viewControllers?.first as? MediaViewerOnePageViewController else {
            preconditionFailure(
                "\(Self.self) must have only one \(MediaViewerOnePageViewController.self)."
            )
        }
        return mediaViewerOnePage
    }
    
    private var destinationPageVCAfterReloading: MediaViewerOnePageViewController?
    
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
    private(set) var navigationBarHiddenBackup = false
    private(set) var navigationBarAlphaBackup = 1.0
    private(set) var toolbarHiddenBackup = true
    private(set) var toolbarAlphaBackup = 1.0
    private(set) var toolbarScrollEdgeAppearanceBackup: UIToolbarAppearance?
    
    // MARK: - Initializers
    
    /// Creates a new viewer.
    /// - Parameters:
    ///   - mediaIdentifier: An identifier for media to view first.
    ///   - dataSource: The data source for the viewer.
    public init<MediaIdentifier>(
        opening mediaIdentifier: MediaIdentifier,
        dataSource: some MediaViewerDataSource<MediaIdentifier>
    ) {
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
        precondition(
            identifiers.contains(mediaIdentifier),
            "mediaIdentifier \(mediaIdentifier) must be included in identifiers returned by dataSource.mediaIdentifiers(for:)."
        )
        
        mediaViewerVM.mediaIdentifiers = identifiers.map(AnyMediaIdentifier.init)
        
        let mediaViewerPage = makeMediaViewerPage(
            with: AnyMediaIdentifier(mediaIdentifier)
        )
        setViewControllers([mediaViewerPage], direction: .forward, animated: false)
        
        hidesBottomBarWhenPushed = true
    }
    
    @available(*, unavailable, message: "init(coder:) is not supported.")
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        navigationBarHiddenBackup = navigationController.isNavigationBarHidden
        navigationBarAlphaBackup = navigationController.navigationBar.alpha
        
        /*
         [Workaround]
         isToolbarHidden returns an incorrect value when the toolbar was
         displayed on a previous screen embedded in UITabBarController.
         */
        toolbarHiddenBackup = navigationController.isToolbarHidden
        toolbarAlphaBackup = navigationController.toolbar.alpha
        
        setUpViews()
        setUpGestureRecognizers()
        setUpSubscriptions()
        
        /*
         NOTE:
         This delegate method is also called at initialization time,
         but since the delegate has not yet been set by the caller,
         it needs to be told to the caller again at this time.
         */
        mediaViewerDelegate?.mediaViewer(
            self,
            didMoveToMediaWith: currentMediaIdentifier
        )
    }
    
    private func setUpViews() {
        // Navigation
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        navigationItem.scrollEdgeAppearance = appearance
        
        // Subviews
        configureBackground(showingMediaOnly: false)
        view.insertSubview(backgroundView, at: 0)
        view.addSubview(pageControlToolbar)
        
        pageControlBar.configure(
            mediaIdentifiers: mediaViewerVM.mediaIdentifiers,
            currentIdentifier: currentMediaIdentifier
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
            .dropFirst() // Skip initial
            .sink { [weak self] showsMediaOnly in
                guard let self, let navigationController else { return }
                shouldHideHomeIndicator = showsMediaOnly
                
                let animator = UIViewPropertyAnimator(
                    duration: UINavigationController.hideShowBarDuration,
                    dampingRatio: 1
                ) {
                    self.tabBarController?.tabBar.isHidden = showsMediaOnly || self.hidesBottomBarWhenPushed
                    navigationController.navigationBar.alpha = showsMediaOnly ? 0 : 1
                    navigationController.toolbar.alpha = showsMediaOnly ? 0 : 1
                    self.configureBackground(showingMediaOnly: showsMediaOnly)
                    self.pageControlToolbar.isHidden = showsMediaOnly
                }
                if showsMediaOnly {
                    animator.addCompletion { position in
                        if position == .end {
                            navigationController.isNavigationBarHidden = true
                            navigationController.isToolbarHidden = true
                        }
                    }
                } else {
                    navigationController.isNavigationBarHidden = false
                    navigationController.isToolbarHidden = false
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
                guard let self else { return }
                switch reason {
                case .tapOnPageThumbnail, .scrollingBar:
                    let identifier = mediaViewerVM.mediaIdentifier(forPage: page)!
                    move(toMediaWith: identifier, animated: false)
                case .configuration, .load, .interactivePaging:
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
    
    open override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        
        guard let navigationController else {
            preconditionFailure(
                "\(Self.self) must be embedded in UINavigationController."
            )
        }
        
        if !mediaViewerVM.showsMediaOnly {
            if navigationController.isNavigationBarHidden {
                navigationController.setNavigationBarHidden(false, animated: animated)
            }
            if navigationController.isToolbarHidden {
                navigationController.setToolbarHidden(false, animated: animated)
            }
        }
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
                 NOTE:
                 This animation will be managed by InteractivePopTransition.
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
    
    /// Fetches type-erased identifiers for media from the data source.
    func fetchMediaIdentifiers() -> [AnyMediaIdentifier] {
        mediaViewerDataSource
            .mediaIdentifiers(for: self)
            .map { AnyMediaIdentifier($0) }
    }
    
    /// Move to media with the specified identifier.
    /// - Parameters:
    ///   - identifier: An identifier for destination media.
    ///   - animated: A Boolean value that indicates whether the transition is to be animated.
    ///   - completion: A closure to be called when the animation completes.
    ///                 It takes a boolean value whether the transition is finished or not.
    open func move<MediaIdentifier>(
        toMediaWith identifier: MediaIdentifier,
        animated: Bool,
        completion: ((Bool) -> Void)? = nil
    ) where MediaIdentifier: Hashable {
        let identifier = AnyMediaIdentifier(identifier)
        move(
            to: makeMediaViewerPage(with: identifier),
            direction: mediaViewerVM.moveDirection(
                from: currentMediaIdentifier,
                to: identifier
            ),
            animated: animated,
            completion: completion
        )
    }
    
    private func move(
        to mediaViewerPage: MediaViewerOnePageViewController,
        direction: NavigationDirection,
        animated: Bool,
        completion: ((Bool) -> Void)? = nil
    ) {
        setViewControllers(
            [mediaViewerPage],
            direction: direction,
            animated: animated,
            completion: completion
        )
    }
    
    private var runningReloadTransactionIDs: Set<UUID> = []
    
    /// Reloads media.
    ///
    /// Updates the UI to reflect the state of the data source, optionally animating the UI changes.
    /// You need to call this method Immediately after `mediaIdentifiers(for:)` provided by
    /// your `MediaViewerDataSource` changes.
    ///
    /// - Parameter animated: Whether to animate the reloading.
    open func reloadMedia(animated: Bool) async {
        let newIdentifiers = fetchMediaIdentifiers()
        let currentIdentifiers = mediaViewerVM.mediaIdentifiers
        guard newIdentifiers != currentIdentifiers else { return }
        
        let deletingIdentifiers = currentIdentifiers.subtracting(
            newIdentifiers
        )
        
        let visibleVCBeforeReloading = currentPageViewController
        
        let pagingAfterReloading = mediaViewerVM.paging(
            afterDeleting: deletingIdentifiers,
            currentIdentifier: visibleVCBeforeReloading.mediaIdentifier
        )
        if let pagingAfterReloading {
            destinationPageVCAfterReloading = makeMediaViewerPage(
                with: pagingAfterReloading.destinationIdentifier
            )
        }
        
        mediaViewerVM.mediaIdentifiers = newIdentifiers
        
        let transactionID = UUID()
        runningReloadTransactionIDs.insert(transactionID)
        
        await pageControlBar.startReloading()
        
        await reloadMedia(
            deleting: deletingIdentifiers,
            visibleVCBeforeReloading: visibleVCBeforeReloading,
            pagingAfterReloading: pagingAfterReloading,
            animated: animated
        )
        
        runningReloadTransactionIDs.remove(transactionID)
        if runningReloadTransactionIDs.isEmpty {
            destinationPageVCAfterReloading = nil
            pageControlBar.finishReloading()
        }
        
        assert(mediaViewerVM.mediaIdentifiers == fetchMediaIdentifiers())
    }
    
    private func reloadMedia(
        deleting deletedIdentifiers: some Sequence<AnyMediaIdentifier>,
        visibleVCBeforeReloading: MediaViewerOnePageViewController,
        pagingAfterReloading: MediaViewerViewModel.PagingAfterReloading?,
        animated: Bool
    ) async {
        let isVisibleMediaDeleted = deletedIdentifiers.contains(
            visibleVCBeforeReloading.mediaIdentifier
        )
        let visiblePageView = visibleVCBeforeReloading.mediaViewerOnePageView
        
        // MARK: Perform vanish animation
        
        let vanishAnimator: UIViewPropertyAnimator?
        if animated {
            /*
             NOTE:
             Play an effect that causes media to disappear.
             This animation will not run if there is no deletion.
             */
            vanishAnimator = UIViewPropertyAnimator(duration: 0.2, curve: .easeOut) {
                if isVisibleMediaDeleted {
                    visiblePageView.performVanishAnimationBody()
                }
                self.pageControlBar.performVanishAnimationBody(
                    for: deletedIdentifiers
                )
            }
        } else {
            // Skip vanish animation
            vanishAnimator = nil
        }
        vanishAnimator?.startAnimation()
        
        // If all media is deleted, close the viewer
        guard let pagingAfterReloading else {
            assert(mediaViewerVM.mediaIdentifiers.isEmpty)
            navigationController?.popViewController(animated: true)
            return
        }
        
        await vanishAnimator?.addCompletion()
        
        // MARK: Finalize reloading
        
        guard let destination = destinationPageVCAfterReloading else {
            assertionFailure(
                "destinationPageVCAfterReloading should not be nil until all reloading transactions have completed."
            )
            return
        }
        
        guard pagingAfterReloading.destinationIdentifier == destination.mediaIdentifier else {
            /*
             NOTE:
             Do not run finishAnimator because another reloading will follow.
             */
            return
        }
        
        func finalizeReloading() {
            pageControlBar.loadItems(
                mediaViewerVM.mediaIdentifiers,
                expandingItemWith: destination.mediaIdentifier,
                animated: animated
            )
            
            if let direction = pagingAfterReloading.direction {
                move(
                    to: destination,
                    direction: direction,
                    animated: animated
                )
            }
        }
        
        if animated {
            let finishAnimator = UIViewPropertyAnimator(
                duration: 0.3,
                dampingRatio: 1,
                animations: finalizeReloading
            )
            finishAnimator.startAnimation()
            await finishAnimator.addCompletion()
        } else {
            finalizeReloading()
        }
    }
    
    private func pageDidChange() {
        mediaViewerDelegate?.mediaViewer(
            self,
            didMoveToMediaWith: currentMediaIdentifier
        )
    }
    
    private func configureBackground(showingMediaOnly: Bool) {
        backgroundView.backgroundColor = showingMediaOnly ? .black : .systemBackground
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
        case .reloading:
            break
        }
    }
    
    // MARK: - Actions
    
    private var canTransitionWithSourceView: Bool {
        switch pageControlBar.state {
        case .collapsing, .collapsed, .expanding, .expanded, .transitioningInteractively:
            return true
        case .reloading:
            /*
             FIXME: A transition with the source view does not work correctly during reloading
             */
            return false
        }
    }
    
    @objc
    private func panned(recognizer: UIPanGestureRecognizer) {
        if recognizer.state == .began {
            // Start the interactive pop transition
            if canTransitionWithSourceView {
                let sourceView = mediaViewerDataSource.mediaViewer(
                    self,
                    transitionSourceViewForMediaWith: currentMediaIdentifier
                )
                interactivePopTransition = .init(sourceView: sourceView)
            }
            
            /*
             [Workaround]
             If the recognizer detects a gesture while the main thread is blocked,
             the interactive transition will not work properly.
             By delaying popViewController with Task, recognizer.state becomes
             `.ended` first and interactivePopTransition becomes nil,
             so a normal transition runs and avoids that problem.
             
             However, it leads to another glitch:
             later interactivePopTransition.panRecognized(by:in:) changes
             the anchor point of the image view while it is still on the
             scroll view, causing the image view to be shifted.
             To avoid it, call prepareForInteractiveTransition(for:) and
             remove the image view from the scroll view in advance.
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
    
    func mediaViewerPageDidZoom(
        _ mediaViewerPage: MediaViewerOnePageViewController
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
    ) -> MediaViewerOnePageViewController {
        let mediaViewerPage = MediaViewerOnePageViewController(
            mediaIdentifier: identifier
        )
        mediaViewerPage.delegate = self
        
        let media = mediaViewerDataSource.mediaViewer(self, mediaWith: identifier)
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
        mediaViewerDataSource.mediaViewer(
            self,
            pageThumbnailForMediaWith: mediaIdentifier,
            filling: preferredThumbnailSize
        )
    }
    
    func mediaViewerPageControlBar(
        _ pageControlBar: MediaViewerPageControlBar,
        widthToHeightOfThumbnailWith mediaIdentifier: AnyMediaIdentifier
    ) -> CGFloat? {
        mediaViewerDataSource.mediaViewer(
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
        
        if operation == .pop,
           mediaViewerDataSource.mediaIdentifiers(for: self).isEmpty {
            // When all media is deleted
            return MediaViewerTransition(
                operation: operation,
                sourceView: nil,
                sourceImage: { nil }
            )
        }
        
        let sourceView: UIView?
        if canTransitionWithSourceView {
            sourceView = interactivePopTransition?.sourceView ?? mediaViewerDataSource.mediaViewer(
                self,
                transitionSourceViewForMediaWith: currentMediaIdentifier
            )
        } else {
            sourceView = nil
        }
        return MediaViewerTransition(
            operation: operation,
            sourceView: sourceView,
            sourceImage: { [weak self] in
                guard let self else { return nil }
                return mediaViewerDataSource.mediaViewer(
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
         [Workaround]
         When pageControlToolbar.clipsToBounds is true,
         toolbar becomes transparent so prevent it.
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
         NOTE:
         Restore toolbar.scrollEdgeAppearance in MediaViewerInteractivePopTransition
         because navigationController has become nil.
         */
        
        NSLayoutConstraint.activate(expandedPageControlToolbarConstraints)
    }
}
