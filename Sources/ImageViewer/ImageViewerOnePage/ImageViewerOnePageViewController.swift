//
//  ImageViewerOnePageViewController.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit
import Combine

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
open class ImageViewerOnePageViewController: UIViewController {
    
    private var cancellables: Set<AnyCancellable> = []
    
    let imageViewerOnePageView: ImageViewerOnePageView
    private let imageViewerOnePageVM = ImageViewerOnePageViewModel()
    
    // MARK: - Initializers
    
    /// Creates a new viewer.
    /// - Parameter image: The image you want to view.
    public init(image: UIImage) {
        self.imageViewerOnePageView = ImageViewerOnePageView(image: image)
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable, message: "init(coder:) is not supported.")
    required public init?(coder: NSCoder) {
        guard let onePageView = ImageViewerOnePageView(coder: coder) else { return nil }
        self.imageViewerOnePageView = onePageView
        super.init(coder: coder)
    }
    
    // MARK: - Override
    
    open override var prefersStatusBarHidden: Bool {
        true
    }
    
    // MARK: - Lifecycle
    
    open override func loadView() {
        view = imageViewerOnePageView
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        setUpSubscriptions()
    }
    
    private func setUpSubscriptions() {
        imageViewerOnePageVM.$showsImageOnly
            .sink { [weak self] showsImageOnly in
                guard let self else { return }
                let animator = UIViewPropertyAnimator(duration: UINavigationController.hideShowBarDuration,
                                                      dampingRatio: 1) {
                    self.navigationController?.navigationBar.alpha = showsImageOnly ? 0 : 1
                    self.view.backgroundColor = showsImageOnly ? .black : .systemBackground
                }
                if showsImageOnly {
                    animator.addCompletion { position in
                        if position == .end {
                            self.navigationController?.isNavigationBarHidden = true
                        }
                    }
                } else {
                    self.navigationController?.isNavigationBarHidden = false
                }
                animator.startAnimation()
            }
            .store(in: &cancellables)
    }
}
