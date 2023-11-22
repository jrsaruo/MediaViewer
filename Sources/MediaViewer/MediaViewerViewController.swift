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
    
    init<MediaIdentifier>(
        rawValue: MediaIdentifier
    ) where MediaIdentifier: Hashable {
        self.rawValue = rawValue
    }
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
    
    var currentMediaIdentifier: AnyMediaIdentifier {
        currentPageViewController.mediaIdentifier
    }
    
    private var destinationPageVCAfterDeletion: MediaViewerOnePageViewController?
    
    var currentPageViewController: MediaViewerOnePageViewController {
        if let destinationPageVCAfterDeletion {
            return destinationPageVCAfterDeletion
        }
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
            with: AnyMediaIdentifier(rawValue: mediaIdentifier)
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
                guard let self else { return }
                switch reason {
                case .tapOnPageThumbnail, .scrollingBar:
                    let identifier = mediaViewerVM.mediaIdentifier(forPage: page)!
                    move(toMediaWith: identifier, animated: false)
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
        self.move(
            toMediaWith: AnyMediaIdentifier(rawValue: identifier),
            animated: animated,
            completion: completion
        )
    }
    
    func move(
        toMediaWith identifier: AnyMediaIdentifier,
        animated: Bool,
        completion: ((Bool) -> Void)? = nil
    ) {
        move(
            toMediaWith: identifier,
            direction: mediaViewerVM.moveDirection(
                from: currentMediaIdentifier,
                to: identifier
            ),
            animated: animated,
            completion: completion
        )
    }
    
    private func move(
        toMediaWith identifier: AnyMediaIdentifier,
        direction: NavigationDirection,
        animated: Bool,
        completion: ((Bool) -> Void)? = nil
    ) {
        setViewControllers(
            [makeMediaViewerPage(with: identifier)],
            direction: direction,
            animated: animated,
            completion: completion
        )
    }
    
    open func reloadMedia() async {
        let newIdentifiers = mediaViewerDataSource
            .mediaIdentifiers(for: self)
            .map { AnyMediaIdentifier(rawValue: $0) }
        
        let (insertions, removals) = newIdentifiers.difference(
            from: mediaViewerVM.mediaIdentifiers
        ).changes
        
        mediaViewerVM.mediaIdentifiers = newIdentifiers
        
        // TODO: Run animations at the same time
        await insertMedia(with: insertions.map(\.element))
        await deleteMedia(with: removals.map(\.element))
    }
    
    private func insertMedia(with identifiers: [AnyMediaIdentifier]) async {
        fatalError("Not implemented.") // TODO: implement
    }
    
    private func deleteMedia(with identifiers: [AnyMediaIdentifier]) async {
        fatalError("Not implemented.") // TODO: implement
    }
    
    /// Deletes media with the specified identifier.
    ///
    /// This method calls the specified `deleteAction`, and if it succeeds, performs the delete animation. If all media is deleted, the viewer will close.
    ///
    /// ```swift
    /// try mediaViewer.deleteMedia(with: imageIdentifier, after: {
    ///     try await your.deleteImage(with: imageIdentifier)
    /// })
    /// ```
    ///
    /// - Note: `deleteAction` must complete deletion until it returns.
    ///         That means the number of media must be reduced by one after the `deleteAction` is succeeded.
    ///         If the deletion fails, `deleteAction` must throw an error.
    /// - Parameters:
    ///   - identifier: An identifier for media to delete.
    ///   - deleteAction: A closure that performs the actual media deletion.
    ///                   It must complete deletion until it returns.
    /// - Throws: If the viewer is not ready to delete (e.g. during paging or delete animation),
    ///           `DeletionError.notReadyToDelete` will be thrown.
    ///           If `deleteAction` throws some error, it will be thrown.
    open func deleteMedia<MediaIdentifier>(
        with identifier: MediaIdentifier,
        after deleteAction: () async throws -> Void
    ) async rethrows where MediaIdentifier: Hashable {
        await pageControlBar.beginDeletion()
        defer { pageControlBar.finishDeletion() }
        
        let identifier = AnyMediaIdentifier(rawValue: identifier)
        let currentPageVC = currentPageViewController
        
        let pagingAfterDeletion = mediaViewerVM.paging(
            afterDeleting: [identifier],
            currentIdentifier: currentPageVC.mediaIdentifier
        )
        
        // MARK: Delete media
        
        let identifiers = mediaViewerDataSource.mediaIdentifiers(for: self)
        precondition(
            mediaViewerVM.mediaIdentifiers.count == identifiers.count
        )
        
        try await deleteAction()
        mediaViewerVM.deleteMediaIdentifier(identifier)
        
        let identifiersAfterDeletion = mediaViewerDataSource.mediaIdentifiers(for: self)
        assert(
            mediaViewerVM.mediaIdentifiers.count == identifiersAfterDeletion.count,
            "You have to complete deletion in `deleteAction` closure."
        )
        
        // MARK: Perform delete animation
        
        let deletionAnimator = UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) {
            if identifier == currentPageVC.mediaIdentifier {
                let currentPageView = currentPageVC.mediaViewerOnePageView
                currentPageView.performDeleteAnimationBody()
            }
            self.pageControlBar.performDeleteAnimationBody(for: [identifier])
        }
        deletionAnimator.startAnimation()
        
        // If all media is deleted, close the viewer
        guard let pagingAfterDeletion else {
            assert(identifiersAfterDeletion.isEmpty)
            navigationController?.popViewController(animated: true)
            return
        }
        
        await deletionAnimator.addCompletion()
        
        // MARK: Finalize deletion
        
        let finishAnimator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1) {
            self.pageControlBar.deleteItems(
                [identifier],
                destinationIdentifier: pagingAfterDeletion.destinationIdentifier,
                animated: true
            )
            
            // Move page if deleted an image on the current page
            if let direction = pagingAfterDeletion.direction {
                /*
                 * NOTE:
                 * move(toPage:animated:) does not work here.
                 * That method uses currentPage, which may crash as it tries
                 * to reference a deleted page.
                 */
                self.move(
                    toMediaWith: pagingAfterDeletion.destinationIdentifier,
                    direction: direction,
                    animated: true
                )
            }
        }
        finishAnimator.startAnimation()
        await finishAnimator.addCompletion()
    }
    
    /// Deletes media on the current page.
    ///
    /// This method calls the specified `deleteAction`, and if it succeeds, performs the delete animation.
    ///
    /// ```swift
    /// try mediaViewer.deleteCurrentMedia(after: { currentImageIdentifier in
    ///     try await your.deleteImage(with: currentImageIdentifier)
    /// })
    /// ```
    ///
    /// If you want to provide the deletion UI in an easy way, you can use `trashButton(deleteAction:)` instead.
    ///
    /// - Note: `deleteAction` must complete deletion until it returns.
    ///         That means the number of media must be reduced by one after the `deleteAction` is succeeded.
    ///         If the deletion fails, `deleteAction` must throw an error.
    /// - Parameter deleteAction: A closure that takes the current media identifier and
    ///                           performs the actual media deletion.
    ///                           It must complete deletion until it returns.
    /// - Throws: If the viewer is not ready to delete (e.g. during paging or delete animation),
    ///           `DeletionError.notReadyToDelete` will be thrown.
    ///           If `deleteAction` throws some error, it will be thrown.
    open func deleteCurrentMedia<MediaIdentifier>(
        after deleteAction: (
            _ currentMediaIdentifier: MediaIdentifier
        ) async throws -> Void
    ) async throws where MediaIdentifier: Hashable {
        let currentIdentifier = self.currentMediaIdentifier.rawValue as! MediaIdentifier
        try await deleteMedia(with: currentIdentifier, after: {
            try await deleteAction(currentIdentifier)
        })
    }
    
    private func pageDidChange() {
        mediaViewerDelegate?.mediaViewer(
            self,
            didMoveToMediaWith: currentMediaIdentifier
        )
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
        case .deleting:
            break
        }
    }
    
    // MARK: - Actions
    
    @objc
    private func panned(recognizer: UIPanGestureRecognizer) {
        guard pageControlBar.state == .expanded else {
            recognizer.state = .failed
            return
        }
        if recognizer.state == .began {
            // Start the interactive pop transition
            let sourceView = mediaViewerDataSource.mediaViewer(
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
        
        let sourceView = interactivePopTransition?.sourceView ?? mediaViewerDataSource.mediaViewer(
            self,
            transitionSourceViewForMediaWith: currentMediaIdentifier
        )
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
