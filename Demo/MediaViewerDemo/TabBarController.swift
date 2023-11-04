//
//  TabBarController.swift
//  MediaViewerDemo
//
//  Created by Yusaku Nishi on 2023/03/28.
//

import UIKit

final class TabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let syncImagesVC = SyncImagesViewController()
        let asyncImagesVC = AsyncImagesViewController()
        let cameraLikeVC = CameraLikeViewController()
        syncImagesVC.tabBarItem = .init(
            title: "Sync",
            image: .init(systemName: "0.circle"),
            tag: 0
        )
        asyncImagesVC.tabBarItem = .init(
            title: "Async",
            image: .init(systemName: "rectangle.stack.fill"),
            tag: 1
        )
        cameraLikeVC.tabBarItem = .init(
            title: "CameraLike",
            image: .init(systemName: "camera.fill"),
            tag: 2
        )
        setViewControllers(
            [
                UINavigationController(rootViewController: syncImagesVC),
                UINavigationController(rootViewController: asyncImagesVC),
                UINavigationController(rootViewController: cameraLikeVC)
            ],
            animated: false
        )
    }
}
