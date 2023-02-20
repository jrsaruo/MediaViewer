//
//  ImageViewerViewController.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit
import Combine

open class ImageViewerViewController: UIViewController {
    
    private var cancellables: Set<AnyCancellable> = []
    
    private let imageViewerView: ImageViewerView
    private let imageViewerVM = ImageViewerViewModel()
    
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
        
        guard navigationController != nil else {
            preconditionFailure("ImageViewerViewController must be embedded in UINavigationController.")
        }
        
        setUpViews()
        setUpSubscriptions()
    }
    
    private func setUpViews() {
        // Subviews
        imageViewerView.singleTapRecognizer.addTarget(self, action: #selector(backgroundTapped))
    }
    
    private func setUpSubscriptions() {
        imageViewerVM.$showsImageOnly
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
    // MARK: - Actions
    
    @objc
    private func backgroundTapped(recognizer: UITapGestureRecognizer) {
        imageViewerVM.showsImageOnly.toggle()
    }
}
