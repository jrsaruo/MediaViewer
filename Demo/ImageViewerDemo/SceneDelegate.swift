//
//  SceneDelegate.swift
//  ImageViewerDemo
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = scene as? UIWindowScene else { return }
        let syncImagesVC = SyncImagesViewController()
        let asyncImagesVC = AsyncImagesViewController()
        syncImagesVC.tabBarItem = .init(title: "Sync", image: .init(systemName: "0.circle"), tag: 0)
        asyncImagesVC.tabBarItem = .init(title: "Async", image: .init(systemName: "rectangle.stack.fill"), tag: 1)
        let tabBarController = UITabBarController()
        tabBarController.setViewControllers(
            [
                UINavigationController(rootViewController: syncImagesVC),
                UINavigationController(rootViewController: asyncImagesVC)
            ],
            animated: false
        )
        window = UIWindow(windowScene: windowScene)
        window!.rootViewController = tabBarController
        window!.makeKeyAndVisible()
    }
}
