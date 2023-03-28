//
//  TabBarController.swift
//  ImageViewerDemo
//
//  Created by Yusaku Nishi on 2023/03/28.
//

import UIKit

final class TabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let syncImagesVC = SyncImagesViewController()
        let asyncImagesVC = AsyncImagesViewController()
        syncImagesVC.tabBarItem = .init(title: "Sync",
                                        image: .init(systemName: "0.circle"),
                                        tag: 0)
        asyncImagesVC.tabBarItem = .init(title: "Async",
                                         image: .init(systemName: "rectangle.stack.fill"),
                                         tag: 1)
        setViewControllers(
            [
                UINavigationController(rootViewController: syncImagesVC),
                UINavigationController(rootViewController: asyncImagesVC)
            ],
            animated: false
        )
    }
}
