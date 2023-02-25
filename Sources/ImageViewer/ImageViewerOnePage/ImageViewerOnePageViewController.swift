//
//  ImageViewerOnePageViewController.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit

/// An image viewer.
///
/// It is recommended to set your `ImageViewerOnePageViewController` instance to `navigationController?.delegate` to enable smooth transition animation.
/// ```swift
/// let imageViewer = ImageViewerOnePageViewController(image: imageToView)
/// imageViewer.dataSource = self
/// navigationController?.delegate = imageViewer
/// navigationController?.pushViewController(imageViewer, animated: true)
/// ```
///
/// - Note: `ImageViewerOnePageViewController` must be used in `UINavigationController`.
final class ImageViewerOnePageViewController: UIViewController {
    
    let imageViewerOnePageView: ImageViewerOnePageView
    
    // MARK: - Initializers
    
    /// Creates a new viewer.
    /// - Parameter image: The image you want to view.
    init(image: UIImage) {
        self.imageViewerOnePageView = ImageViewerOnePageView(image: image)
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable, message: "init(coder:) is not supported.")
    required init?(coder: NSCoder) {
        guard let onePageView = ImageViewerOnePageView(coder: coder) else { return nil }
        self.imageViewerOnePageView = onePageView
        super.init(coder: coder)
    }
    
    // MARK: - Override
    
    override var prefersStatusBarHidden: Bool {
        true
    }
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = imageViewerOnePageView
    }
}
