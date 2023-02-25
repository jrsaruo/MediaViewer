//
//  ImageViewerOnePageViewController.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit

final class ImageViewerOnePageViewController: UIViewController {
    
    let imageViewerOnePageView: ImageViewerOnePageView
    let page: Int
    
    let imageDoubleTapRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer()
        recognizer.numberOfTapsRequired = 2
        return recognizer
    }()
    
    // MARK: - Initializers
    
    init(image: UIImage, page: Int) {
        self.imageViewerOnePageView = ImageViewerOnePageView(image: image)
        self.page = page
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable, message: "init(coder:) is not supported.")
    required init?(coder: NSCoder) {
        guard let onePageView = ImageViewerOnePageView(coder: coder) else { return nil }
        self.imageViewerOnePageView = onePageView
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
        imageDoubleTapRecognizer.addTarget(self, action: #selector(imageDoubleTapped))
        imageViewerOnePageView.imageView.addGestureRecognizer(imageDoubleTapRecognizer)
    }
    
    // MARK: - Actions
    
    @objc
    private func imageDoubleTapped(recognizer: UITapGestureRecognizer) {
        imageViewerOnePageView.updateZoomScaleOnDoubleTap(recognizedBy: recognizer)
    }
}
