//
//  SceneDelegate.swift
//  MediaViewerDemo
//
//  Created by Yusaku Nishi on 2023/02/19.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: windowScene)
        window!.rootViewController = TabBarController()
        window!.makeKeyAndVisible()
    }
}
