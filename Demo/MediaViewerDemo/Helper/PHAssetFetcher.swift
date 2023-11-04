//
//  PHAssetFetcher.swift
//  MediaViewerDemo
//
//  Created by Yusaku Nishi on 2023/11/04.
//

import UIKit

#if swift(>=5.9)
import Photos
#else
// PHAsset does not conform to Sendable
@preconcurrency import Photos
#endif

enum PHAssetFetcher {
    
    static func fetchImageAssets() async -> [PHAsset] {
        await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        
        let result = PHAsset.fetchAssets(with: .image, options: nil)
        return result.objects(at: IndexSet(integersIn: 0..<result.count))
    }
    
    static func fetchImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .none
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: .zero,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
