//
//  AsyncImagesViewController.swift
//  ImageViewerDemo
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit
import ImageViewer
import SwiftyTable
@preconcurrency import Photos

final class AsyncImagesViewController: UIViewController {
    
    private let imageGridView = ImageGridView()
    
    private lazy var dataSource = UICollectionViewDiffableDataSource<Int, PHAsset>(collectionView: imageGridView.collectionView) { [weak self] collectionView, indexPath, asset in
        guard let self else { return nil }
        let cell = collectionView.dequeueReusableCell(of: ImageCell.self, for: indexPath)
        cell.configure(with: asset,
                       contentMode: self.preferredContentMode,
                       screenScale: self.view.window!.screen.scale)
        return cell
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
        
        toggleContentModeButton.primaryAction = UIAction(image: .init(systemName: "rectangle.arrowtriangle.2.inward")) { [weak self] _ in
            self?.toggleContentMode()
        }
        navigationItem.rightBarButtonItem = toggleContentModeButton
    }
    
    private nonisolated func fetchAssets() async -> [PHAsset] {
        await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        
        let result = PHAsset.fetchAssets(with: .image, options: nil)
        return result.objects(at: IndexSet(integersIn: 0 ..< result.count))
    }
    
    private func loadPhotos() async {
        let assets = await fetchAssets()
        
        // Hide the collection view until ready
        imageGridView.collectionView.isHidden = true
        defer {
            UIView.transition(with: imageGridView.collectionView,
                              duration: 0.2,
                              options: [.transitionCrossDissolve, .curveEaseInOut, .allowUserInteraction]) {
                self.imageGridView.collectionView.isHidden = false
            }
        }
        
        var snapshot = dataSource.snapshot()
        snapshot.appendSections([0])
        snapshot.appendItems(assets)
        await dataSource.apply(snapshot, animatingDifferences: false)
        
        // Scroll to the bottom if needed
        if let lastAsset = assets.last {
            imageGridView.collectionView.scrollToItem(at: dataSource.indexPath(for: lastAsset)!,
                                                      at: .bottom,
                                                      animated: false)
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
        let imageViewer = ImageViewerViewController(page: indexPath.item, dataSource: self)
        imageViewer.imageViewerDelegate = self
        Task {
            imageViewer.toolbar.items = [
                .init(image: .init(systemName: "square.and.arrow.up")),
                .flexibleSpace(),
                .init(image: .init(systemName: "heart")),
                .flexibleSpace(),
                .init(image: .init(systemName: "info.circle")),
                .flexibleSpace(),
                .init(systemItem: .trash)
            ]
        }
        navigationController?.delegate = imageViewer
        navigationController?.pushViewController(imageViewer, animated: true)
    }
}

// MARK: - ImageViewerDataSource -

extension AsyncImagesViewController: ImageViewerDataSource {
    
    func numberOfImages(in imageViewer: ImageViewerViewController) -> Int {
        dataSource.snapshot().numberOfItems
    }
    
    func imageViewer(_ imageViewer: ImageViewerViewController,
                     imageSourceOnPage page: Int) -> ImageSource {
        let asset = dataSource.snapshot().itemIdentifiers[page]
        return .async {
            return await withCheckedContinuation { continuation in
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.resizeMode = .none
                options.isNetworkAccessAllowed = true
                PHImageManager.default()
                    .requestImage(for: asset,
                                  targetSize: .zero,
                                  contentMode: .aspectFit,
                                  options: options) { image, _ in
                        continuation.resume(returning: image)
                    }
            }
        }
    }
    
    func imageViewer(_ imageViewer: ImageViewerViewController,
                     imageWidthToHeightOnPage page: Int) -> CGFloat? {
        let asset = dataSource.snapshot().itemIdentifiers[page]
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = true
        var size: CGSize?
        PHImageManager.default()
            .requestImage(for: asset,
                          targetSize: CGSize(width: 100, height: 100),
                          contentMode: .aspectFit,
                          options: options) { image, _ in
                size = image?.size
            }
        guard let size, size.height > 0 else { return nil }
        return size.width / size.height
    }
    
    func imageViewer(_ imageViewer: ImageViewerViewController,
                     pageThumbnailOnPage page: Int,
                     filling preferredThumbnailSize: CGSize) -> ImageSource {
        let asset = dataSource.snapshot().itemIdentifiers[page]
        return .async(transition: .fade(duration: 0.1)) {
            return await withCheckedContinuation { continuation in
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                PHImageManager.default()
                    .requestImage(for: asset,
                                  targetSize: preferredThumbnailSize,
                                  contentMode: .aspectFill,
                                  options: options) { image, _ in
                        continuation.resume(returning: image)
                    }
            }
        }
    }
    
    func transitionSourceView(forCurrentPageOf imageViewer: ImageViewerViewController) -> UIImageView? {
        let currentPage = imageViewer.currentPage
        let indexPathForCurrentImage = IndexPath(item: currentPage, section: 0)
        guard let cellForCurrentImage = imageGridView.collectionView.cellForItem(at: indexPathForCurrentImage) as? ImageCell else {
            return nil
        }
        return cellForCurrentImage.imageView
    }
}

// MARK: - ImageViewerDelegate -

extension AsyncImagesViewController: ImageViewerDelegate {
    
    func imageViewer(_ imageViewer: ImageViewerViewController, didMoveTo page: Int) {
        let asset = dataSource.snapshot().itemIdentifiers[page]
        let dateDescription = asset.creationDate?.formatted()
        imageViewer.title = dateDescription
    }
}
