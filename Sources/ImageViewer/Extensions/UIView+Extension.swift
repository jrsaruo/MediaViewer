//
//  UIView+Extension.swift
//  
//
//  Created by Yusaku Nishi on 2023/02/25.
//

import UIKit

extension UIView {
    
    /// Update the anchor point while keeping its position fixed.
    /// - Parameter newAnchorPoint: The new anchor point.
    func updateAnchorPointWithoutMoving(_ newAnchorPoint: CGPoint) {
        frame.origin.x += (newAnchorPoint.x - anchorPoint.x) * frame.width
        frame.origin.y += (newAnchorPoint.y - anchorPoint.y) * frame.height
        anchorPoint = newAnchorPoint
    }
}
