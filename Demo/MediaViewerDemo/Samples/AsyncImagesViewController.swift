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
    
    private let toggleContentModeButton = UIBarButtonItem()
    
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
        
        toggleContentModeButton.primaryAction = UIAction(
            image: .init(systemName: "rectangle.arrowtriangle.2.inward")
        ) { [weak self] _ in
            self?.toggleContentMode()
        }
        navigationItem.rightBarButtonItem = toggleContentModeButton
    }
    
    private func loadPhotos() async {
        let assets = await PHAssetFetcher.fetchImageAssets()
        
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
        
        var snapshot = dataSource.snapshot()
        snapshot.appendSections([0])
        snapshot.appendItems(assets)
        await dataSource.apply(snapshot, animatingDifferences: false)
        
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
}

// MARK: - UICollectionViewDelegate -

extension AsyncImagesViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let mediaViewer = MediaViewerViewController(page: indexPath.item, dataSource: self)
        mediaViewer.mediaViewerDelegate = self
        mediaViewer.toolbarItems = [
            .init(image: .init(systemName: "square.and.arrow.up")),
            .flexibleSpace(),
            .init(image: .init(systemName: "heart")),
            .flexibleSpace(),
            .init(image: .init(systemName: "info.circle")),
            .flexibleSpace(),
            .init(systemItem: .trash)
        ]
        navigationController?.delegate = mediaViewer
        navigationController?.pushViewController(mediaViewer, animated: true)
    }
}

// MARK: - MediaViewerDataSource -

extension AsyncImagesViewController: MediaViewerDataSource {
    
    func numberOfMedia(in mediaViewer: MediaViewerViewController) -> Int {
        dataSource.snapshot().numberOfItems
    }
    
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        mediaOnPage page: Int
    ) -> Media {
        let asset = dataSource.snapshot().itemIdentifiers[page]
        return .async { await PHAssetFetcher.fetchImage(for: asset) }
    }
    
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        mediaWidthToHeightOnPage page: Int
    ) -> CGFloat? {
        let asset = dataSource.snapshot().itemIdentifiers[page]
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = true
        var size: CGSize?
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 100, height: 100),
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            size = image?.size
        }
        guard let size, size.height > 0 else { return nil }
        return size.width / size.height
    }
    
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        pageThumbnailOnPage page: Int,
        filling preferredThumbnailSize: CGSize
    ) -> Source<UIImage?> {
        let asset = dataSource.snapshot().itemIdentifiers[page]
        return .async(transition: .fade(duration: 0.1)) {
            await withCheckedContinuation { continuation in
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: preferredThumbnailSize,
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    continuation.resume(returning: image)
                }
            }
        }
    }
    
    func transitionSourceView(forCurrentPageOf mediaViewer: MediaViewerViewController) -> UIImageView? {
        let currentPage = mediaViewer.currentPage
        let indexPathForCurrentImage = IndexPath(item: currentPage, section: 0)
        
        // NOTE: Without this, later cellForItem(at:) sometimes returns nil.
        imageGridView.collectionView.layoutIfNeeded()
        
        guard let cellForCurrentImage = imageGridView.collectionView.cellForItem(
            at: indexPathForCurrentImage
        ) as? ImageCell else {
            return nil
        }
        return cellForCurrentImage.imageView
    }
}

// MARK: - MediaViewerDelegate -

extension AsyncImagesViewController: MediaViewerDelegate {
    
    func mediaViewer(_ mediaViewer: MediaViewerViewController, didMoveToPage page: Int) {
        let asset = dataSource.snapshot().itemIdentifiers[page]
        let dateDescription = asset.creationDate?.formatted()
        mediaViewer.title = dateDescription
    }
}
