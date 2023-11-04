//
//  CameraLikeViewController.swift
//  MediaViewerDemo
//
//  Created by Yusaku Nishi on 2023/11/04.
//

import UIKit

#if swift(>=5.9)
import Photos
#else
// PHAsset does not conform to Sendable
@preconcurrency import Photos
#endif

final class CameraLikeViewController: UIViewController {
    
    private let cameraLikeView = CameraLikeView()
    
    private var assets: [PHAsset] = []
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = cameraLikeView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpViews()
        
        Task {
            await loadPhotos()
        }
    }
    
    private func setUpViews() {
        title = "CameraLike"
        
        // Navigation
        navigationItem.backButtonDisplayMode = .minimal
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    private func loadPhotos() async {
        assets = await PHImageFetcher.imageAssets()
        await showLatestPhotoAsThumbnail()
    }
    
    private func showLatestPhotoAsThumbnail() async {
        guard let latestAsset = assets.last else { return }
        
        let showLibraryButton = cameraLikeView.showLibraryButton
        let scale = view.window?.windowScene?.screen.scale ?? 3
        let latestImage = await PHImageFetcher.image(
            for: latestAsset,
            targetSize: CGSize(
                width: showLibraryButton.bounds.width * scale,
                height: showLibraryButton.bounds.height * scale
            ),
            contentMode: .aspectFill,
            resizeMode: .fast
        )
        showLibraryButton.configuration?.background.image = latestImage
    }
}

// MARK: - CameraLikeView -

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
