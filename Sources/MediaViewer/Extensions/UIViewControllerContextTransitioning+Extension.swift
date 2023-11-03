//
//  UIViewControllerContextTransitioning+Extension.swift
//
//
//  Created by Yusaku Nishi on 2023/11/03.
//

import UIKit

extension UIViewControllerContextTransitioning {
    
    /// Notifies the system that the transition animation is done.
    func completeTransition() {
        completeTransition(!transitionWasCancelled)
    }
}
