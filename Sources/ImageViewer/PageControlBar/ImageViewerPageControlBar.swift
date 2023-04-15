//
//  ImageViewerPageControlBar.swift
//  
//
//  Created by Yusaku Nishi on 2023/03/18.
//

import UIKit
import Combine

@MainActor
protocol ImageViewerPageControlBarDataSource: AnyObject {
    func imageViewerPageControlBar(_ pageControlBar: ImageViewerPageControlBar,
                                   thumbnailOnPage page: Int,
                                   filling preferredThumbnailSize: CGSize) -> ImageSource
}

final class ImageViewerPageControlBar: UIView {
    
    enum State {
        case collapsing
        
        /// The collapsed state during scroll.
        /// - Parameters:
        ///   - indexPathForFinalDestinationItem: The index path for where you will eventually arrive after ending dragging.
        case collapsed(indexPathForFinalDestinationItem: IndexPath?)
        
        case expanding
        case expanded
        
        var indexPathForFinalDestinationItem: IndexPath? {
            guard case .collapsed(let indexPath) = self else { return nil }
            return indexPath
        }
    }
    
    weak var dataSource: (any ImageViewerPageControlBarDataSource)?
    
    private var state: State = .collapsed(indexPathForFinalDestinationItem: nil)
    
    private var indexPathForCurrentCenterItem: IndexPath? {
        let offsetX = collectionView.contentOffset.x
        let center = CGPoint(x: offsetX + collectionView.bounds.width / 2, y: 0)
        return collectionView.indexPathForItem(at: center)
    }
    
    // MARK: Publishers
    
    var pageDidChange: some Publisher<Int, Never> {
        _pageDidChange.removeDuplicates()
    }
    private let _pageDidChange = PassthroughSubject<Int, Never>()
    
    // MARK: UI components
    
    private var layout: ImageViewerPageControlBarLayout {
        collectionView.collectionViewLayout as! ImageViewerPageControlBarLayout
    }
    
    private lazy var collectionView: UICollectionView = {
        let layout = ImageViewerPageControlBarLayout(style: .collapsed)
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
        
        diffableDataSource.apply(snapshot) {
            let indexPath = IndexPath(item: currentPage, section: 0)
            self.expandAndScrollToItem(at: indexPath, animated: false)
        }
    }
    
    private func updateLayout(expandingItemAt indexPath: IndexPath?,
                              animated: Bool) {
        let style: ImageViewerPageControlBarLayout.Style
        if let indexPath {
            style = .expanded(indexPath, preferredExpandingImageSize: nil)
        } else {
            style = .collapsed
        }
        let layout = ImageViewerPageControlBarLayout(style: style)
        collectionView.setCollectionViewLayout(layout, animated: animated)
    }
    
    private func expandAndScrollToItem(at indexPath: IndexPath, animated: Bool) {
        state = .expanding
        _pageDidChange.send(indexPath.item)
        
        func expandAndScroll() {
            updateLayout(expandingItemAt: indexPath, animated: false)
            collectionView.scrollToItem(at: indexPath,
                                        at: .centeredHorizontally,
                                        animated: false)
            state = .expanded
        }
        if animated {
            UIViewPropertyAnimator(duration: 0.5, dampingRatio: 1) {
                expandAndScroll()
            }.startAnimation()
        } else {
            expandAndScroll()
        }
    }
    
    private func expandAndScrollToCenterItem(animated: Bool) {
        guard let indexPathForCurrentCenterItem else { return }
        expandAndScrollToItem(at: indexPathForCurrentCenterItem,
                              animated: animated)
    }
    
    private func collapseItem() {
        guard let indexPath = layout.style.indexPathForExpandingItem else { return }
        self.state = .collapsing
        UIViewPropertyAnimator(duration: 0.5, dampingRatio: 1) {
            self.updateLayout(expandingItemAt: nil, animated: false)
            self.collectionView.scrollToItem(at: indexPath,
                                             at: .centeredHorizontally,
                                             animated: false)
            self.state = .collapsed(indexPathForFinalDestinationItem: nil)
        }.startAnimation()
    }
}

// MARK: - UICollectionViewDelegate -

extension ImageViewerPageControlBar: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        
        if layout.style.indexPathForExpandingItem != indexPath {
            expandAndScrollToItem(at: indexPath, animated: true)
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        collapseItem()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        switch state {
        case .collapsed(let indexPathForFinalDestinationItem):
            guard let indexPathForCurrentCenterItem,
                  scrollView.isDragging else { return }
            _pageDidChange.send(indexPathForCurrentCenterItem.item)
            
            /*
             * NOTE:
             * Start expanding when the final destination approaches.
             * However, if the destination is the first or last item,
             * ignore it and wait until the scroll is done
             * because the scroll may bounce on the edge.
             */
            if indexPathForCurrentCenterItem == indexPathForFinalDestinationItem,
               !isEdgeIndexPath(indexPathForCurrentCenterItem) {
                expandAndScrollToCenterItem(animated: true)
            }
        case .collapsing, .expanding, .expanded:
            break
        }
    }
    
    private func isEdgeIndexPath(_ indexPath: IndexPath) -> Bool {
        switch indexPath.item {
        case 0, collectionView.numberOfItems(inSection: 0) - 1:
            return true
        default:
            return false
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let targetPoint = CGPoint(
            x: targetContentOffset.pointee.x + collectionView.adjustedContentInset.left,
            y: 0
        )
        let targetIndexPath = collectionView.indexPathForItem(at: targetPoint)
        state = .collapsed(
            indexPathForFinalDestinationItem: targetIndexPath
        )
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        /*
         * When the finger is released with the finger stopped
         * or
         * when the finger is released at the point where it exceeds the limit of left and right edges.
         */
        if !scrollView.isDragging {
            guard let indexPath = indexPathForCurrentCenterItem ?? state.indexPathForFinalDestinationItem else {
                return
            }
            expandAndScrollToItem(at: indexPath, animated: true)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        switch state {
        case .collapsing, .collapsed:
            expandAndScrollToCenterItem(animated: true)
        case .expanding, .expanded:
            break // NOP
        }
    }
}
