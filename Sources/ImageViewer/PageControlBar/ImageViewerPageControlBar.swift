//
//  ImageViewerPageControlBar.swift
//  
//
//  Created by Yusaku Nishi on 2023/03/18.
//

import UIKit

@MainActor
protocol ImageViewerPageControlBarDataSource: AnyObject {
    func imageViewerPageControlBar(_ pageControlBar: ImageViewerPageControlBar,
                                   thumbnailOnPage page: Int,
                                   filling preferredThumbnailSize: CGSize) -> ImageSource
}

@MainActor
protocol ImageViewerPageControlBarDelegate: AnyObject {
    func imageViewerPageControlBar(_ pageControlBar: ImageViewerPageControlBar,
                                   didVisitThumbnailOnPage page: Int)
}

final class ImageViewerPageControlBar: UIView {
    
    weak var dataSource: (any ImageViewerPageControlBarDataSource)?
    weak var delegate: (any ImageViewerPageControlBarDelegate)?
    
    private var layout: ImageViewerPageControlBarLayout {
        collectionView.collectionViewLayout as! ImageViewerPageControlBarLayout
    }
    
    private lazy var collectionView: UICollectionView = {
        let layout = ImageViewerPageControlBarLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        return collectionView
    }()
    
    lazy var diffableDataSource = UICollectionViewDiffableDataSource<Int, Int>(collectionView: collectionView) { [weak self] collectionView, indexPath, page in
        guard let self else { return nil }
        return collectionView.dequeueConfiguredReusableCell(using: self.cellRegistration,
                                                            for: indexPath,
                                                            item: page)
    }
    
    private lazy var cellRegistration = UICollectionView.CellRegistration<PageControlBarThumbnailCell, Int> { [weak self] cell, indexPath, page in
        guard let self, let dataSource = self.dataSource else { return }
        let scale = self.window?.screen.scale ?? 3
        let preferredSize = CGSize(width: cell.bounds.width * scale,
                                   height: cell.bounds.height * scale)
        let thumbnailSource = dataSource.imageViewerPageControlBar(
            self,
            thumbnailOnPage: page,
            filling: preferredSize
        )
        cell.configure(with: thumbnailSource)
    }
    
    private var shouldDetectScrolling = true
    
    private var indexPathForCurrentCenterItem: IndexPath? {
        let offsetX = collectionView.contentOffset.x
        let center = CGPoint(x: offsetX + collectionView.bounds.width / 2, y: 0)
        return collectionView.indexPathForItem(at: center)
    }
    
    // MARK: - Initializers
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpViews()
    }
    
    private func setUpViews() {
        // FIXME: [Workaround] Initialize cellRegistration before applying a snapshot to diffableDataSource.
        _ = cellRegistration
        
        // Subviews
        collectionView.delegate = self
        addSubview(collectionView)
        
        // Layout
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    // MARK: - Override
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: super.intrinsicContentSize.width,
               height: 42)
    }
    
    // MARK: - Lifecycle
    
    override func layoutSubviews() {
        super.layoutSubviews()
        adjustContentInset()
    }
    
    private func adjustContentInset() {
        guard bounds.width > 0 else { return }
        let offset = (bounds.width - layout.compactItemWidth) / 2
        collectionView.contentInset = .init(top: 0,
                                            left: offset,
                                            bottom: 0,
                                            right: offset)
    }
    
    // MARK: - Methods
    
    func configure(numberOfPages: Int, currentPage: Int) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        snapshot.appendItems(Array(0 ..< numberOfPages))
        
        // Ignore scrolling until setup is complete
        shouldDetectScrolling = false
        diffableDataSource.apply(snapshot) {
            let indexPath = IndexPath(item: currentPage, section: 0)
            self.updateLayout(expandingItemAt: indexPath, animated: false)
            self.scroll(toPage: currentPage, animated: false)
            self.shouldDetectScrolling = true
        }
    }
    
    func scroll(toPage page: Int, animated: Bool) {
        let indexPath = IndexPath(item: page, section: 0)
        collectionView.scrollToItem(at: indexPath,
                                    at: .centeredHorizontally,
                                    animated: animated)
    }
    
    private func updateLayout(expandingItemAt indexPath: IndexPath?,
                              animated: Bool) {
        let layout = ImageViewerPageControlBarLayout()
        layout.indexPathForExpandingItem = indexPath
        collectionView.setCollectionViewLayout(layout, animated: animated)
    }
    
    private func expandAndScrollToItem(at indexPath: IndexPath) {
        UIViewPropertyAnimator(duration: 0.5, dampingRatio: 1) {
            self.updateLayout(expandingItemAt: indexPath, animated: false)
            self.collectionView.scrollToItem(at: indexPath,
                                             at: .centeredHorizontally,
                                             animated: false)
        }.startAnimation()
    }
    
    private func expandAndScrollToCenterItem() {
        guard let indexPathForCurrentCenterItem else { return }
        expandAndScrollToItem(at: indexPathForCurrentCenterItem)
    }
    
    private func collapseItem() {
        guard let indexPath = layout.indexPathForExpandingItem else { return }
        UIViewPropertyAnimator(duration: 0.5, dampingRatio: 1) {
            self.updateLayout(expandingItemAt: nil, animated: false)
            self.collectionView.scrollToItem(at: indexPath,
                                             at: .centeredHorizontally,
                                             animated: false)
        }.startAnimation()
    }
}

// MARK: - UICollectionViewDelegate -

extension ImageViewerPageControlBar: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        
        if layout.indexPathForExpandingItem != indexPath {
            delegate?.imageViewerPageControlBar(self, didVisitThumbnailOnPage: indexPath.item)
            expandAndScrollToItem(at: indexPath)
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        collapseItem()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard shouldDetectScrolling else { return }
        if let indexPathForCurrentCenterItem,
           layout.indexPathForExpandingItem != indexPathForCurrentCenterItem {
            layout.indexPathForExpandingItem = indexPathForCurrentCenterItem
            if scrollView.isDragging {
                delegate?.imageViewerPageControlBar(self, didVisitThumbnailOnPage: indexPathForCurrentCenterItem.item)
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        expandAndScrollToCenterItem()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            expandAndScrollToCenterItem()
        }
    }
}
