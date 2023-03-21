//
//  UIImageView+Extension.swift
//  
//
//  Created by Yusaku Nishi on 2023/03/22.
//

import UIKit

extension UIImageView {
    
    func load(from imageSource: ImageSource) {
        switch imageSource {
        case .sync(let image):
            self.image = image
        case .async(let transition, let imageProvider):
            Task.detached(priority: .high) {
                let image = await imageProvider()
                Task { @MainActor in
                    switch transition {
                    case .fade(let duration):
                        UIView.transition(with: self,
                                          duration: duration,
                                          options: [.transitionCrossDissolve, .curveEaseInOut, .allowUserInteraction]) {
                            self.image = image
                        }
                    case .none:
                        self.image = image
                    }
                }
            }
        }
    }
}
