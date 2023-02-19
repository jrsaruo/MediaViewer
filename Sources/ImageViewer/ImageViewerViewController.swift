//
//  ImageViewerViewController.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit

public final class ImageViewerViewController: UINavigationController {
    
    public init() {
        super.init(rootViewController: ImageViewerContentViewController())
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setViewControllers([ImageViewerContentViewController()], animated: false)
    }
}

final class ImageViewerContentViewController: UIViewController {
    
    // MARK: - Lifecycle
    
    override public func loadView() {
        view = ImageViewerView()
    }
}
