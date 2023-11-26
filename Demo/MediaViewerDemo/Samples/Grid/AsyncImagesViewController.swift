//
//  AsyncImagesViewController.swift
//  MediaViewerDemo
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit
import MediaViewer

#if swift(>=5.9)
import Photos
#else
// PHAsset does not conform to Sendable
@preconcurrency import Photos
#endif

final class AsyncImagesViewController: UIViewController {
    
    private typealias CellRegistration = UICollectionView.CellRegistration<
        ImageCell,
        (asset: PHAsset, contentMode: UIView.ContentMode, screenScale: CGFloat)
    >
    
    private let imageGridView = ImageGridView()
    
    private let cellRegistration = CellRegistration { cell, _, item in
        cell.configure(
            with: item.asset,
            contentMode: item.contentMode,
            screenScale: item.screenScale
        )
    }
    
    private lazy var dataSource = UICollectionViewDiffableDataSource<Int, PHAsset>(
        collectionView: imageGridView.collectionView
    ) { [weak self] collectionView, indexPath, asset in
        guard let self else { return nil }
        return collectionView.dequeueConfiguredReusableCell(
            using: self.cellRegistration,
            for: indexPath,
            item: (
                asset: asset,
                contentMode: self.preferredContentMode,
                screenScale: self.view.window?.screen.scale ?? 3
            )
        )
    }
    
    private lazy var refreshButton = UIBarButtonItem(
        systemItem: .refresh,
        primaryAction: .init { [weak self] _ in
            Task { await self?.refresh(animated: true) }
        }
    )
    
    private lazy var toggleContentModeButton = UIBarButtonItem(
        primaryAction: .init(
            image: .init(systemName: "rectangle.arrowtriangle.2.inward")
        ) { [weak self] _ in
            self?.toggleContentMode()
        }
    )
    
    private var preferredContentMode: UIView.ContentMode = .scaleAspectFill
    
    // MARK: - Lifecycle
    
    override func loadView() {
        imageGridView.collectionView.delegate = self
        view = imageGridView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpViews()
        
        Task(priority: .high) {
            await loadPhotos()
        }
    }
    
    private func setUpViews() {
        // Navigation
        navigationItem.title = "Async Sample"
        navigationItem.backButtonDisplayMode = .minimal
        navigationItem.leftBarButtonItem = refreshButton
        navigationItem.rightBarButtonItem = toggleContentModeButton
        
        // Subviews
        imageGridView.collectionView.refreshControl = .init(
            frame: .zero,
            primaryAction: .init { [weak self] _ in
                Task { await self?.refresh(animated: true) }
            }
        )
    }
    
    private func loadPhotos() async {
        // Hide the collection view until ready
        imageGridView.collectionView.isHidden = true
        defer {
            UIView.transition(
                with: imageGridView.collectionView,
                duration: 0.2,
                options: [.transitionCrossDissolve, .curveEaseInOut, .allowUserInteraction]
            ) {
                self.imageGridView.collectionView.isHidden = false
            }
        }
        
        let assets = await refresh(animated: false)
        
        // Scroll to the bottom if needed
        if let lastAsset = assets.last {
            imageGridView.collectionView.scrollToItem(
                at: dataSource.indexPath(for: lastAsset)!,
                at: .bottom,
                animated: false
            )
        }
    }
    
    // MARK: - Methods
    
    @discardableResult
    private func refresh(animated: Bool) async -> [PHAsset] {
        let assets = await PHImageFetcher.imageAssets()
        
        var snapshot = NSDiffableDataSourceSnapshot<Int, PHAsset>()
        snapshot.appendSections([0])
        snapshot.appendItems(assets)
        await dataSource.apply(snapshot, animatingDifferences: animated)
        
        imageGridView.collectionView.refreshControl?.endRefreshing()
        return assets
    }
    
    private func toggleContentMode() {
        let newContentMode: UIView.ContentMode
        let systemImageName: String
        if preferredContentMode == .scaleAspectFill {
            newContentMode = .scaleAspectFit
            systemImageName = "rectangle.arrowtriangle.2.outward"
        } else {
            newContentMode = .scaleAspectFill
            systemImageName = "rectangle.arrowtriangle.2.inward"
        }
        preferredContentMode = newContentMode
        toggleContentModeButton.image = .init(systemName: systemImageName)
        
        // Reload to reflect new content mode
        var snapshot = dataSource.snapshot()
        let visibleItems = dataSource.snapshot(for: 0).visibleItems
        snapshot.reloadItems(visibleItems)
        Task {
            await dataSource.apply(snapshot)
        }
    }
    
    // Fake removal (not actually delete photo)
    private func removeAsset(_ asset: PHAsset) async {
        var snapshot = dataSource.snapshot()
        snapshot.deleteItems([asset])
        await dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate -

extension AsyncImagesViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset = dataSource.itemIdentifier(for: indexPath)!
        let mediaViewer = MediaViewerViewController(opening: asset, dataSource: self)
        mediaViewer.mediaViewerDelegate = self
        mediaViewer.toolbarItems = [
            .init(image: .init(systemName: "square.and.arrow.up")),
            .flexibleSpace(),
            .init(image: .init(systemName: "heart")),
            .flexibleSpace(),
            .init(image: .init(systemName: "info.circle")),
            .flexibleSpace(),
            mediaViewer.trashButton { button, currentAsset in
                try? await self.showConfirmationForPhotoRemoval(
                    from: button,
                    on: mediaViewer,
                    removingAsset: currentAsset
                )
            }
        ]
        navigationController?.delegate = mediaViewer
        navigationController?.pushViewController(mediaViewer, animated: true)
    }
    
    private func showConfirmationForPhotoRemoval(
        from button: UIBarButtonItem,
        on mediaViewer: MediaViewerViewController,
        removingAsset: PHAsset
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let actionSheet = UIAlertController(
                title: "Do you simulate photo removal?",
                message: "The photo won't actually be deleted.",
                preferredStyle: .actionSheet
            )
            let removeAction = UIAlertAction(
                title: "Simulate",
                style: .default
            ) { _ in
                Task {
                    await self.removeAsset(removingAsset)
                    continuation.resume()
                }
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                continuation.resume(throwing: CancellationError())
            }
            actionSheet.addAction(removeAction)
            actionSheet.addAction(cancelAction)
            actionSheet.popoverPresentationController?.sourceItem = button
            mediaViewer.present(actionSheet, animated: true)
        }
    }
}

// MARK: - MediaViewerDataSource -

extension AsyncImagesViewController: MediaViewerDataSource {
    
    func mediaIdentifiers(for mediaViewer: MediaViewerViewController) -> [PHAsset] {
        dataSource.snapshot().itemIdentifiers
    }
    
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        mediaWith mediaIdentifier: PHAsset
    ) -> Media {
        .async { await PHImageFetcher.image(for: mediaIdentifier) }
    }
    
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        widthToHeightOfMediaWith mediaIdentifier: PHAsset
    ) -> CGFloat? {
        let size = PHImageFetcher.imageSize(of: mediaIdentifier)
        guard let size, size.height > 0 else { return nil }
        return size.width / size.height
    }
    
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        pageThumbnailForMediaWith mediaIdentifier: PHAsset,
        filling preferredThumbnailSize: CGSize
    ) -> Source<UIImage?> {
        .async(transition: .fade(duration: 0.1)) {
            await PHImageFetcher.image(
                for: mediaIdentifier,
                targetSize: preferredThumbnailSize,
                contentMode: .aspectFill,
                resizeMode: .fast
            )
        }
    }
    
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        transitionSourceViewForMediaWith mediaIdentifier: PHAsset
    ) -> UIView? {
        let indexPathForCurrentImage = dataSource.indexPath(for: mediaIdentifier)!
        
        let collectionView = imageGridView.collectionView
        
        // NOTE: Without this, later cellForItem(at:) sometimes returns nil.
        if !collectionView.indexPathsForVisibleItems.contains(indexPathForCurrentImage) {
            collectionView.scrollToItem(
                at: indexPathForCurrentImage,
                at: .centeredVertically,
                animated: false
            )
        }
        collectionView.layoutIfNeeded()
        
        guard let cellForCurrentImage = collectionView.cellForItem(at: indexPathForCurrentImage) as? ImageCell else {
            return nil
        }
        return cellForCurrentImage.imageView
    }
}

// MARK: - MediaViewerDelegate -

extension AsyncImagesViewController: MediaViewerDelegate {
    
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        didMoveToMediaWith mediaIdentifier: PHAsset
    ) {
        let dateDescription = mediaIdentifier.creationDate?.formatted()
        mediaViewer.title = dateDescription
    }
}
