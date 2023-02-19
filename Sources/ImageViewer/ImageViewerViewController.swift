//
//  ImageViewerViewController.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit

public final class ImageViewerViewController: UIViewController {
    
    // MARK: - Lifecycle
    
    override public func loadView() {
        view = ImageViewerView()
    }
}
