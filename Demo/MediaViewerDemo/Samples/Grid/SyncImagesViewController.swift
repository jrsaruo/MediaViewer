//
//  SyncImagesViewController.swift
//  MediaViewerDemo
//
//  Created by Yusaku Nishi on 2023/03/05.
//

import UIKit
import MediaViewer

final class SyncImagesViewController: UIViewController {
    
    struct Item: Hashable {
        let number: Int
        let image: UIImage
        
        @MainActor
        init(number: Int) {
            self.number = number
            self.image = ImageFactory
                .circledText("\(number)", width: 1000)
                .withTintColor(.tintColor)
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.number == rhs.number
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(number)
        }
    }
    
    private typealias CellRegistration = UICollectionView.CellRegistration<
        ImageCell,
        (image: UIImage, contentMode: UIView.ContentMode)
    >
    
    private let imageGridView = ImageGridView()
    
    private let cellRegistration = CellRegistration { cell, _, item in
        cell.configure(with: item.image, contentMode: item.contentMode)
    }
    
    private lazy var dataSource = UICollectionViewDiffableDataSource<Int, Item>(
        collectionView: imageGridView.collectionView
    ) { [weak self] collectionView, indexPath, item in
        guard let self else { return nil }
        return collectionView.dequeueConfiguredReusableCell(
            using: self.cellRegistration,
            for: indexPath,
            item: (image: item.image, contentMode: .scaleAspectFill)
        )
    }
    
    private lazy var refreshButton = UIBarButtonItem(
        systemItem: .refresh,
        primaryAction: .init { [weak self] _ in
            Task { self?.refresh() }
        }
    )
    
    // MARK: - Lifecycle
    
    override func loadView() {
        imageGridView.collectionView.delegate = self
        view = imageGridView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpViews()
        refresh()
    }
    
    private func setUpViews() {
        // Navigation
        navigationItem.title = "Sync Sample"
        navigationItem.backButtonDisplayMode = .minimal
        navigationItem.leftBarButtonItem = refreshButton
        
        // Subviews
        imageGridView.collectionView.refreshControl = .init(
            frame: .zero,
            primaryAction: .init { [weak self] _ in
                self?.refresh()
            }
        )
    }
    
    private func refresh() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, Item>()
        snapshot.appendSections([0])
        snapshot.appendItems((0...20).map(Item.init))
        dataSource.apply(snapshot)
        imageGridView.collectionView.refreshControl?.endRefreshing()
    }
    
    private func insertNewItem(after item: Item) {
        var snapshot = dataSource.snapshot()
        let maxItem = snapshot.itemIdentifiers.max { $0.number < $1.number }!
        let newItem = Item(number: maxItem.number + 1)
        snapshot.insertItems([newItem], afterItem: item)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    private func removeItem(_ item: Item) {
        var snapshot = dataSource.snapshot()
        snapshot.deleteItems([item])
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate -

extension SyncImagesViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let image = dataSource.itemIdentifier(for: indexPath)!
        let mediaViewer = MediaViewerViewController(opening: image, dataSource: self)
        mediaViewer.toolbarItems = [
            .flexibleSpace(),
            .init(
                systemItem: .add,
                primaryAction: .init { [unowned mediaViewer] _ in
                    self.insertNewItem(
                        after: mediaViewer.currentMediaIdentifier()
                    )
                    Task {
                        await mediaViewer.reloadMedia()
                    }
                }
            ),
            .flexibleSpace(),
            mediaViewer.trashButton { _, currentMediaIdentifier in
                self.removeItem(currentMediaIdentifier)
            }
        ]
        navigationController?.delegate = mediaViewer
        navigationController?.pushViewController(mediaViewer, animated: true)
    }
}

// MARK: - MediaViewerDataSource -

extension SyncImagesViewController: MediaViewerDataSource {
    
    func mediaIdentifiers(for mediaViewer: MediaViewerViewController) -> [Item] {
        dataSource.snapshot().itemIdentifiers
    }
    
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        mediaWith mediaIdentifier: Item
    ) -> Media {
        .sync(mediaIdentifier.image)
    }
    
    func mediaViewer(
        _ mediaViewer: MediaViewerViewController,
        transitionSourceViewForMediaWith mediaIdentifier: Item
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
