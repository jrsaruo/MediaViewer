//
//  ImageViewerView.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit

final class ImageViewerView: UIView {
    
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
        backgroundColor = .systemBackground
    }
}
