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
        button.layer.cornerRadius = 4
        button.layer.cornerCurve = .continuous
        return button
    }()
    
    let toggleTabBarHiddenButton: UIButton = {
        var configuration = UIButton.Configuration.borderedTinted()
        configuration.buttonSize = .small
        configuration.title = "Hide Tab Bar"
        return UIButton(configuration: configuration)
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
    
    private let buttonArea: UIView = {
        let view = UIView()
        view.backgroundColor = .black.withAlphaComponent(0.1)
        return view
    }()
    
    private let shutterButtonWidth = 68.0
    
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
        addSubview(buttonArea)
        buttonArea.addSubview(shutterButton)
        buttonArea.addSubview(showLibraryButton)
        buttonArea.addSubview(toggleTabBarHiddenButton)
        
        shutterButton.layer.cornerRadius = shutterButtonWidth / 2
        
        // Layout
        showLibraryButton.autoLayout { item in
            item.leading.equal(to: layoutMarginsGuide)
            item.centerY.equal(to: shutterButton)
            item.size.equal(toSquare: 48)
        }
        
        toggleTabBarHiddenButton.autoLayout { item in
            item.trailing.equal(to: layoutMarginsGuide)
            item.centerY.equal(to: shutterButton)
        }
        
        switch traitCollection.horizontalSizeClass {
        case .unspecified, .compact:
            layoutForCompactScreen()
        case .regular:
            layoutForRegularScreen()
        @unknown default:
            fatalError()
        }
    }
    
    private func layoutForCompactScreen() {
        previewView.autoLayout { item in
            item.top.equal(to: safeAreaLayoutGuide, plus: 44)
            item.width.equal(to: item.height, multipliedBy: 3.0 / 4)
            item.leadingTrailing.equalToSuperview()
        }
        
        buttonArea.autoLayout { item in
            item.top.equal(to: previewView.bottomAnchor)
            item.leadingTrailing.equalToSuperview()
            item.bottom.equal(to: safeAreaLayoutGuide)
        }
        
        shutterButton.autoLayout { item in
            item.center.equalToSuperview()
            item.size.equal(toSquare: shutterButtonWidth)
        }
    }
    
    private func layoutForRegularScreen() {
        previewView.autoLayout { item in
            item.edges.equalToSuperview()
        }
        
        buttonArea.autoLayout { item in
            item.leadingTrailing.equalToSuperview()
            item.bottom.equalToSuperview()
        }
        
        shutterButton.autoLayout { item in
            item.centerX.equalToSuperview()
            item.top.equalToSuperview(plus: 16)
            item.bottom.equal(to: safeAreaLayoutGuide, plus: -16)
            item.size.equal(toSquare: shutterButtonWidth)
        }
    }
}

