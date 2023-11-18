//
//  MediaViewerOnePageViewController.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit

@MainActor
protocol MediaViewerOnePageViewControllerDelegate: AnyObject {
    func mediaViewerPageTapped(_ mediaViewerPage: MediaViewerOnePageViewController)
    
    func mediaViewerPage(
        _ mediaViewerPage: MediaViewerOnePageViewController,
        didDoubleTap imageView: UIImageView
    )
}

final class MediaViewerOnePageViewController: UIViewController {
    
    let mediaIdentifier: AnyMediaIdentifier
    
    weak var delegate: (any MediaViewerOnePageViewControllerDelegate)?
    
    let mediaViewerOnePageView = MediaViewerOnePageView()
    
    let singleTapRecognizer = UITapGestureRecognizer()
    
    let imageDoubleTapRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer()
        recognizer.numberOfTapsRequired = 2
        return recognizer
    }()
    
    // MARK: - Initializers
    
    init(mediaIdentifier: AnyMediaIdentifier) {
        self.mediaIdentifier = mediaIdentifier
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable, message: "init(coder:) is not supported.")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = mediaViewerOnePageView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpGestureRecognizers()
    }
    
    private func setUpGestureRecognizers() {
        singleTapRecognizer.addTarget(self, action: #selector(singleTapped))
        view.addGestureRecognizer(singleTapRecognizer)
        
        imageDoubleTapRecognizer.addTarget(self, action: #selector(imageDoubleTapped))
        mediaViewerOnePageView.imageView.addGestureRecognizer(imageDoubleTapRecognizer)
        
        // Dependencies
        singleTapRecognizer.require(toFail: imageDoubleTapRecognizer)
    }
    
    override func viewWillTransition(
        to size: CGSize,
        with coordinator: any UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Update layout when screen is rotated
        coordinator.animate { context in
            self.mediaViewerOnePageView.invalidateLayout()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        mediaViewerOnePageView.scrollView.zoomScale = 1
    }
    
    // MARK: - Actions
    
    @objc
    private func singleTapped() {
        delegate?.mediaViewerPageTapped(self)
    }
    
    @objc
    private func imageDoubleTapped(recognizer: UITapGestureRecognizer) {
        delegate?.mediaViewerPage(self, didDoubleTap: mediaViewerOnePageView.imageView)
        mediaViewerOnePageView.updateZoomScaleOnDoubleTap(recognizedBy: recognizer)
    }
}
