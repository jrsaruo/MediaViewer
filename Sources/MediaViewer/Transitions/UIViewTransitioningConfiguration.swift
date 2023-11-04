//
//  UIViewTransitioningConfiguration.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/23.
//

import UIKit

/// The set of view properties to be animated during transitions.
struct UIViewTransitioningConfiguration {
    var alpha: CGFloat
    var backgroundColor: UIColor?
    var tintColor: UIColor?
    var contentMode: UIView.ContentMode
    var cornerRadius: CGFloat
    var borderColor: CGColor?
    var borderWidth: CGFloat
    var masksToBounds: Bool
}

extension UIView {
    
    var transitioningConfiguration: UIViewTransitioningConfiguration {
        get {
            .init(
                alpha: alpha,
                backgroundColor: backgroundColor,
                tintColor: tintColor,
                contentMode: contentMode,
                cornerRadius: layer.cornerRadius,
                borderColor: layer.borderColor,
                borderWidth: layer.borderWidth,
                masksToBounds: layer.masksToBounds
            )
        }
        set {
            alpha = newValue.alpha
            backgroundColor = newValue.backgroundColor
            tintColor = newValue.tintColor
            contentMode = newValue.contentMode
            layer.cornerRadius = newValue.cornerRadius
            layer.borderColor = newValue.borderColor
            layer.borderWidth = newValue.borderWidth
            layer.masksToBounds = newValue.masksToBounds
        }
    }
}
