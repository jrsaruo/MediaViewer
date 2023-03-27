//
//  ImageViewerOnePageViewController.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit

protocol ImageViewerOnePageViewControllerDelegate: AnyObject {
    func imageViewerPageTapped(_ imageViewerPage: ImageViewerOnePageViewController)
    
    func imageViewerPage(_ imageViewerPage: ImageViewerOnePageViewController,
                         didDoubleTap imageView: UIImageView)
}

final class ImageViewerOnePageViewController: UIViewController {
    
    let page: Int
    
    weak var delegate: (any ImageViewerOnePageViewControllerDelegate)?
    
    let imageViewerOnePageView = ImageViewerOnePageView()
    
    let singleTapRecognizer = UITapGestureRecognizer()
    
    let imageDoubleTapRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer()
        recognizer.numberOfTapsRequired = 2
        return recognizer
    }()
    
    // MARK: - Initializers
    
    init(page: Int) {
        self.page = page
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable, message: "init(coder:) is not supported.")
    required init?(coder: NSCoder) {
        self.page = 0
        super.init(coder: coder)
    }
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = imageViewerOnePageView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpGestureRecognizers()
    }
    
    private func setUpGestureRecognizers() {
        singleTapRecognizer.addTarget(self, action: #selector(singleTapped))
        view.addGestureRecognizer(singleTapRecognizer)
        
        imageDoubleTapRecognizer.addTarget(self, action: #selector(imageDoubleTapped))
        imageViewerOnePageView.imageView.addGestureRecognizer(imageDoubleTapRecognizer)
        
        // Dependencies
        singleTapRecognizer.require(toFail: imageDoubleTapRecognizer)
    }
    
    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Update layout when screen is rotated
        coordinator.animate { context in
            self.imageViewerOnePageView.invalidateLayout()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        imageViewerOnePageView.scrollView.zoomScale = 1
    }
    
    // MARK: - Actions
    
    @objc
    private func singleTapped() {
        delegate?.imageViewerPageTapped(self)
    }
    
    @objc
    private func imageDoubleTapped(recognizer: UITapGestureRecognizer) {
        delegate?.imageViewerPage(self, didDoubleTap: imageViewerOnePageView.imageView)
        imageViewerOnePageView.updateZoomScaleOnDoubleTap(recognizedBy: recognizer)
    }
}
