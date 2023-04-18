//
//  UICollectionView+Extension.swift
//  
//
//  Created by Yusaku Nishi on 2023/04/18.
//

import UIKit

extension UICollectionView {
    
    var indexPathForHorizontalCenterItem: IndexPath? {
        let centerX = CGPoint(x: contentOffset.x + bounds.width / 2, y: 0)
        return indexPathForItem(at: centerX)
    }
}
