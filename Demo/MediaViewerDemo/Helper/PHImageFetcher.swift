//
//  PHImageFetcher.swift
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

enum PHImageFetcher {
    
    static func fetchImageAssets() async -> [PHAsset] {
        await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        
        let result = PHAsset.fetchAssets(with: .image, options: nil)
        return result.objects(at: IndexSet(integersIn: 0..<result.count))
    }
    
    static func fetchImage(
        for asset: PHAsset,
        targetSize: CGSize = .zero,
        contentMode: PHImageContentMode = .aspectFit,
        resizeMode: PHImageRequestOptionsResizeMode = .none
    ) async -> UIImage? {
        await PHImageManager.default().image(
            for: asset,
            targetSize: targetSize,
            contentMode: contentMode,
            resizeMode: resizeMode
        )
    }
    
    static func imageSize(of asset: PHAsset) -> CGSize? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = true
        var size: CGSize?
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 100, height: 100),
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            size = image?.size
        }
        return size
    }
}

extension PHImageManager {
    
    func image(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        resizeMode: PHImageRequestOptionsResizeMode
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = resizeMode
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
