//
//  ImageViewerViewController.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit

public final class ImageViewerViewController: UINavigationController {
    
    public init(image: UIImage) {
        super.init(rootViewController: ImageViewerContentViewController(image: image))
    }
    
    @available(*, unavailable, message: "init(coder:) is not supported.")
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        guard let imageViewerContentVC = ImageViewerContentViewController(coder: coder) else { return nil }
        setViewControllers([imageViewerContentVC], animated: false)
    }
}

final class ImageViewerContentViewController: UIViewController {
    
    private let imageViewerView: ImageViewerView
    
    // MARK: - Initializers
    
    init(image: UIImage) {
        self.imageViewerView = ImageViewerView(image: image)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        guard let imageViewerView = ImageViewerView(coder: coder) else { return nil }
        self.imageViewerView = imageViewerView
        super.init(coder: coder)
    }
    
    // MARK: - Lifecycle
    
    override public func loadView() {
        view = imageViewerView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
    }
    
    private func setUpViews() {
        // Navigation
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Subviews
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        view.addGestureRecognizer(tapRecognizer)
    }
    
    // MARK: - Actions
    
    @objc
    private func backgroundTapped(recognizer: UITapGestureRecognizer) {
        guard let navigationController else { return }
        navigationController.setNavigationBarHidden(!navigationController.isNavigationBarHidden,
                                                    animated: true)
    }
}
