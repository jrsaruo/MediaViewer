//
//  ImageViewerViewController.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/25.
//

import UIKit

open class ImageViewerViewController: UIPageViewController {
    
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
}
