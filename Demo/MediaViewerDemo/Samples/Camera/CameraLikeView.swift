//
//  CameraLikeView.swift
//  MediaViewerDemo
//
//  Created by Yusaku Nishi on 2023/11/04.
//

import UIKit

final class CameraLikeView: UIView {
    
    let showLibraryButton: UIButton = {
        var configuration = UIButton.Configuration.borderedProminent()
        configuration.baseBackgroundColor = .secondarySystemBackground
        configuration.background.cornerRadius = 4
        configuration.background.imageContentMode = .scaleAspectFill
        let button = UIButton(configuration: configuration)
        button.contentMode = .scaleAspectFill
        button.clipsToBounds = true
        return button
    }()
    
    private let previewView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        return view
    }()
    
    private let shutterButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .white
        return button
    }()
    
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
        
        // Subviews
        addSubview(previewView)
        addSubview(shutterButton)
        addSubview(showLibraryButton)
        
        let bottomAreaLayoutGuide = UILayoutGuide()
        addLayoutGuide(bottomAreaLayoutGuide)
        
        // Layout
        previewView.autoLayout { item in
            item.top.equal(to: safeAreaLayoutGuide, plus: 44)
            item.width.equal(to: item.height, multipliedBy: 3.0 / 4)
            item.leadingTrailing.equalToSuperview()
        }
        
        bottomAreaLayoutGuide.autoLayout { item in
            item.top.equal(to: previewView.bottomAnchor)
            item.leadingTrailing.equalToSuperview()
            item.bottom.equal(to: safeAreaLayoutGuide)
        }
        
        let shutterButtonWidth = 68.0
        shutterButton.layer.cornerRadius = shutterButtonWidth / 2
        shutterButton.autoLayout { item in
            item.center.equal(to: bottomAreaLayoutGuide)
            item.size.equal(toSquare: shutterButtonWidth)
        }
        
        showLibraryButton.autoLayout { item in
            item.leading.equal(to: layoutMarginsGuide)
            item.centerY.equal(to: bottomAreaLayoutGuide)
            item.size.equal(toSquare: 48)
        }
    }
}

