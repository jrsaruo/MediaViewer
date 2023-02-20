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
            group.interItemSpacing = .fixed(1)
            
            let section = NSCollectionLayoutSection(group: group)
            return section
        }
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(PhotoCell.self)
        return collectionView
    }()
    
    private lazy var dataSource = UICollectionViewDiffableDataSource<Int, UIImage>(collectionView: collectionView) { collectionView, indexPath, photo in
        let cell = collectionView.dequeueReusableCell(of: PhotoCell.self, for: indexPath)
        cell.image = photo
        return cell
    }
    
    // MARK: - Lifecycle
    
    override func loadView() {
        collectionView.delegate = self
        view = collectionView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Photos"
        navigationItem.backButtonDisplayMode = .minimal
        
        var snapshot = dataSource.snapshot()
        snapshot.appendSections([0])
        snapshot.appendItems((0...20).map { UIImage(systemName: "\($0).circle")! })
        dataSource.apply(snapshot)
    }
}

// MARK: - UICollectionViewDelegate -

extension PhotosViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let imageViewer = ImageViewerViewController()
        present(imageViewer, animated: true)
    }
}
