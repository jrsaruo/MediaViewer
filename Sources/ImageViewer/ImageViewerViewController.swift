//
//  ImageViewerViewController.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit

open class ImageViewerViewController: UIViewController {
    
    private let imageViewerView: ImageViewerView
    
    // MARK: - Initializers
    
    public init(image: UIImage) {
        self.imageViewerView = ImageViewerView(image: image)
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable, message: "init(coder:) is not supported.")
    required public init?(coder: NSCoder) {
        guard let imageViewerView = ImageViewerView(coder: coder) else { return nil }
        self.imageViewerView = imageViewerView
        super.init(coder: coder)
    }
    
    // MARK: - Override
    
    open override var prefersStatusBarHidden: Bool {
        true
    }
    
    // MARK: - Lifecycle
    
    open override func loadView() {
        view = imageViewerView
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
    }
    
    private func setUpViews() {
        guard let navigationController else {
            preconditionFailure("ImageViewerViewController must be embedded in UINavigationController.")
        }
        
        // Navigation
        navigationController.setNavigationBarHidden(true, animated: false)
        
        // Subviews
        imageViewerView.singleTapRecognizer.addTarget(self, action: #selector(backgroundTapped))
    }
    
    // MARK: - Actions
    
    @objc
    private func backgroundTapped(recognizer: UITapGestureRecognizer) {
        guard let navigationController else { return }
        navigationController.setNavigationBarHidden(!navigationController.isNavigationBarHidden,
                                                    animated: true)
    }
}
