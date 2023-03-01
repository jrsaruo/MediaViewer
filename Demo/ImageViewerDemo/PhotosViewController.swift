//
//  PhotosViewController.swift
//  ImageViewerDemo
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit
import ImageViewer
import SwiftyTable

final class PhotosViewController: UIViewController {
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, layoutEnvironment in
            let columnCount = 3
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(130)
                ),
                repeatingSubitem: .init(layoutSize: .init(
                    widthDimension: .fractionalWidth(1 / CGFloat(columnCount)),
                    heightDimension: .estimated(130)
                )),
                count: columnCount
            )
            group.interItemSpacing = .fixed(2)
            
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 2
            return section
        }
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(PhotoCell.self)
        return collectionView
    }()
    
    private lazy var dataSource = UICollectionViewDiffableDataSource<Int, UIImage>(collectionView: collectionView) { [weak self] collectionView, indexPath, photo in
        guard let self else { return nil }
        let cell = collectionView.dequeueReusableCell(of: PhotoCell.self, for: indexPath)
        cell.imageView.image = photo
        cell.imageView.contentMode = self.preferredContentMode
        return cell
    }
    
    private let toggleContentModeButton = UIBarButtonItem()
    
    private var preferredContentMode: UIView.ContentMode = .scaleAspectFill
    
    // MARK: - Lifecycle
    
    override func loadView() {
        collectionView.delegate = self
        view = collectionView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
    }
    
    private func setUpViews() {
        title = "Photos"
        
        // Navigation
        navigationItem.backButtonDisplayMode = .minimal
        
        toggleContentModeButton.primaryAction = UIAction(image: .init(systemName: "rectangle.arrowtriangle.2.inward")) { [weak self] _ in
            self?.toggleContentMode()
        }
        navigationItem.rightBarButtonItem = toggleContentModeButton
        
        // Subviews
        var snapshot = dataSource.snapshot()
        snapshot.appendSections([0])
        snapshot.appendItems((0...20).map { UIImage(systemName: "\($0).circle")! })
        dataSource.apply(snapshot)
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
        
        var snapshot = dataSource.snapshot()
        let visibleItems = dataSource.snapshot(for: 0).visibleItems
        snapshot.reloadItems(visibleItems)
        dataSource.apply(snapshot)
    }
}

// MARK: - UICollectionViewDelegate -

extension PhotosViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let imageViewer = ImageViewerViewController(page: indexPath.item)
        imageViewer.imageViewerDataSource = self
        navigationController?.delegate = imageViewer
        navigationController?.pushViewController(imageViewer, animated: true)
    }
}

// MARK: - ImageViewerDataSource -

extension PhotosViewController: ImageViewerDataSource {
    
    func images(in imageViewer: ImageViewerViewController) -> [UIImage] {
        dataSource.snapshot().itemIdentifiers
    }
    
    func thumbnailView(forCurrentPageOf imageViewer: ImageViewerViewController) -> UIImageView? {
        let currentPage = imageViewer.currentPage
        let indexPathForCurrentImage = IndexPath(item: currentPage, section: 0)
        guard let cellForCurrentImage = collectionView.cellForItem(at: indexPathForCurrentImage) as? PhotoCell else {
            return nil
        }
        return cellForCurrentImage.imageView
    }
}
