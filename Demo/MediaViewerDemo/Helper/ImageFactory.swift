//
//  ImageFactory.swift
//  MediaViewerDemo
//
//  Created by Yusaku Nishi on 2023/11/04.
//

import SwiftUI

enum ImageFactory {
    
    @MainActor
    static func circledText(_ text: String, width: CGFloat) -> UIImage {
        ImageRenderer(
            content: CircledTextView(text: text, width: width)
        )
        .uiImage!
        .withRenderingMode(.alwaysTemplate)
    }
}

struct CircledTextView: View {
    
    let text: String
    let width: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: width / 20)
                .padding(width / 10)
            
            Text(text)
                .font(
                    .system(
                        size: width / 2,
                        weight: .semibold,
                        design: .rounded
                    )
                )
        }
        .frame(width: width, height: width)
    }
}

@available(iOS 17, *)
#Preview(traits: .fixedLayout(width: 300, height: 300)) {
    Image(
        uiImage: ImageFactory.circledText("1", width: 300)
    )
    .foregroundStyle(.blue)
}
