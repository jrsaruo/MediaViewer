//
//  ImageViewerViewController.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/25.
//

import UIKit

open class ImageViewerViewController: UIPageViewController {
    
    open weak var imageViewerDataSource: ImageViewerDataSource?
    
    // MARK: Backups
    
    private var navigationBarScrollEdgeAppearanceBackup: UINavigationBarAppearance?
    private var navigationBarHiddenBackup = false
    
    // MARK: - Initializers
    
    public init(image: UIImage) {
        super.init(transitionStyle: .scroll,
                   navigationOrientation: .horizontal,
                   options: [
                    .interPageSpacing: 16,
                    .spineLocation: SpineLocation.none.rawValue
                   ])
        let imageViewer = ImageViewerOnePageViewController(image: image)
        setViewControllers([imageViewer], direction: .forward, animated: false)
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Lifecycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let navigationController else {
            preconditionFailure("ImageViewerOnePageViewController must be embedded in UINavigationController.")
        }
        
        navigationBarScrollEdgeAppearanceBackup = navigationController.navigationBar.scrollEdgeAppearance
        navigationBarHiddenBackup = navigationController.isNavigationBarHidden
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        navigationController?.navigationBar.scrollEdgeAppearance = navigationBarScrollEdgeAppearanceBackup
        navigationController?.setNavigationBarHidden(navigationBarHiddenBackup, animated: animated)
    }
}

extension ImageViewerViewController: UINavigationControllerDelegate {
    
}
