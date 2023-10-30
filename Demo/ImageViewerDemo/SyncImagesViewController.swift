//
//  SyncImagesViewController.swift
//  ImageViewerDemo
//
//  Created by Yusaku Nishi on 2023/03/05.
//

import UIKit
import ImageViewer
import SwiftyTable

final class SyncImagesViewController: UIViewController {
    
    private let imageGridView = ImageGridView()
    
    private lazy var dataSource = UICollectionViewDiffableDataSource<Int, UIImage>(
        collectionView: imageGridView.collectionView
    ) { [weak self] collectionView, indexPath, image in
        guard let self else { return nil }
        let cell = collectionView.dequeueReusableCell(of: ImageCell.self, for: indexPath)
        cell.configure(with: image, contentMode: .scaleAspectFill)
        return cell
    }
    
    // MARK: - Lifecycle
    
    override func loadView() {
        imageGridView.collectionView.delegate = self
        view = imageGridView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
    }
    
    private func setUpViews() {
        // Navigation
        navigationItem.title = "Sync Sample"
        navigationItem.backButtonDisplayMode = .minimal
        
        // Subviews
        var snapshot = dataSource.snapshot()
        snapshot.appendSections([0])
        snapshot.appendItems((0...20).map { UIImage(systemName: "\($0).circle")! })
        dataSource.apply(snapshot)
    }
}

// MARK: - UICollectionViewDelegate -

extension SyncImagesViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let imageViewer = ImageViewerViewController(page: indexPath.item, dataSource: self)
        navigationController?.delegate = imageViewer
        navigationController?.pushViewController(imageViewer, animated: true)
    }
}

// MARK: - ImageViewerDataSource -

extension SyncImagesViewController: ImageViewerDataSource {
    
    func numberOfImages(in imageViewer: ImageViewerViewController) -> Int {
        dataSource.snapshot().numberOfItems
    }
    
    func imageViewer(
        _ imageViewer: ImageViewerViewController,
        imageSourceOnPage page: Int
    ) -> ImageSource {
        .sync(dataSource.snapshot().itemIdentifiers[page])
    }
    
    func transitionSourceView(
        forCurrentPageOf imageViewer: ImageViewerViewController
    ) -> UIImageView? {
        let currentPage = imageViewer.currentPage
        let indexPathForCurrentImage = IndexPath(item: currentPage, section: 0)
        
        // NOTE: Without this, later cellForItem(at:) sometimes returns nil.
        imageGridView.collectionView.layoutIfNeeded()
        
        guard let cellForCurrentImage = imageGridView.collectionView.cellForItem(at: indexPathForCurrentImage) as? ImageCell else {
            return nil
        }
        return cellForCurrentImage.imageView
    }
}
