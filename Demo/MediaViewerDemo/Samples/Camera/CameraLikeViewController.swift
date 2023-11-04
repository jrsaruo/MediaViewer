//
//  CameraLikeViewController.swift
//  MediaViewerDemo
//
//  Created by Yusaku Nishi on 2023/11/04.
//

import UIKit

final class CameraLikeViewController: UIViewController {
    
    private let cameraLikeView = CameraLikeView()
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = cameraLikeView
    }
}

// MARK: - CameraLikeView -

final class CameraLikeView: UIView {
    
    // MARK: - Initializers
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpViews()
    }
    
    private func setUpViews() {
        backgroundColor = .black
    }
}
