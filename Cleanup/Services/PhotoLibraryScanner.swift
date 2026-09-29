import Foundation
import Photos
import UIKit
import CoreImage
import Combine

@MainActor
class PhotoLibraryScanner: ObservableObject {
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0.0
    @Published var statusMessage: String = ""
    
    @Published var photoGroups: [PhotoGroup] = []
    @Published var screenshots: [PhotoAssetItem] = []
    @Published var largeVideos: [PhotoAssetItem] = []
    @Published var blurryPhotos: [PhotoAssetItem] = []
    @Published var allPhotos: [PhotoAssetItem] = []
    
    @Published var totalSimilarBytes: Int64 = 0
    @Published var totalScreenshotBytes: Int64 = 0
    @Published var totalVideoBytes: Int64 = 0
    @Published var totalBlurryBytes: Int64 = 0
    @Published var totalAllPhotosBytes: Int64 = 0
    
    private var assetSizeCache: [String: Int64] = [:]
    
    func scanAll() async {
        isScanning = true
        scanProgress = 0.0
        
        statusMessage = "Accessing Photo Library..."
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            isScanning = false
            return
        }
        
        // 1. Scan All Photos
        statusMessage = "Loading All Photos..."
        scanProgress = 0.15
        await scanAllPhotos()
        
        // 2. Scan Screenshots
        statusMessage = "Finding Screenshots..."
        scanProgress = 0.35
        await scanScreenshots()
        
        // 3. Scan Large Videos
        statusMessage = "Analyzing Videos..."
        scanProgress = 0.55
        await scanVideos()
        
        // 4. Scan Similar Photos
        statusMessage = "Grouping Similar Photos..."
        scanProgress = 0.75
        await scanSimilarPhotos()
        
        // 5. Scan Blurry Photos
        statusMessage = "Detecting Low Quality Photos..."
        scanProgress = 0.95
        await scanBlurryPhotos()
        
        scanProgress = 1.0
        statusMessage = "Scan Complete"
        isScanning = false
    }
    
    // MARK: - All Photos Scanner
    func scanAllPhotos() async {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var items: [PhotoAssetItem] = []
        var totalBytes: Int64 = 0
        
        result.enumerateObjects { asset, _, _ in
            let size = self.getFileSize(for: asset)
            let item = PhotoAssetItem(
                id: asset.localIdentifier,
                asset: asset,
                fileSize: size,
                creationDate: asset.creationDate,
                pixelWidth: asset.pixelWidth,
                pixelHeight: asset.pixelHeight,
                isSelected: false,
                isBest: false
            )
            items.append(item)
            totalBytes += size
        }
        
        self.allPhotos = items
        self.totalAllPhotosBytes = totalBytes
    }
    
    // MARK: - Screenshots Scanner
    func scanScreenshots() async {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "(mediaSubtype & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var items: [PhotoAssetItem] = []
        var totalBytes: Int64 = 0
        
        result.enumerateObjects { asset, _, _ in
            let size = self.getFileSize(for: asset)
            let item = PhotoAssetItem(
                id: asset.localIdentifier,
                asset: asset,
                fileSize: size,
                creationDate: asset.creationDate,
                pixelWidth: asset.pixelWidth,
                pixelHeight: asset.pixelHeight,
                isSelected: false,
                isBest: false
            )
            items.append(item)
            totalBytes += size
        }
        
        self.screenshots = items
        self.totalScreenshotBytes = totalBytes
    }
    
    // MARK: - Large Videos Scanner
    func scanVideos() async {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let result = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        var items: [PhotoAssetItem] = []
        var totalBytes: Int64 = 0
        
        result.enumerateObjects { asset, _, _ in
            let size = self.getFileSize(for: asset)
            let item = PhotoAssetItem(
                id: asset.localIdentifier,
                asset: asset,
                fileSize: size,
                creationDate: asset.creationDate,
                pixelWidth: asset.pixelWidth,
                pixelHeight: asset.pixelHeight,
                isSelected: false,
                isBest: false
            )
            items.append(item)
            totalBytes += size
        }
        
        items.sort(by: { $0.fileSize > $1.fileSize })
        
        self.largeVideos = items
        self.totalVideoBytes = totalBytes
    }
    
    // MARK: - Highly Efficient Similar / Duplicate Photos Scanner
    func scanSimilarPhotos() async {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d AND (mediaSubtype & %d) == 0", PHAssetMediaType.image.rawValue, PHAssetMediaSubtype.photoScreenshot.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var allAssets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            allAssets.append(asset)
        }
        
        var groups: [PhotoGroup] = []
        var currentCluster: [PHAsset] = []
        var lastDate: Date? = nil
        var lastRatio: Double? = nil
        
        for asset in allAssets {
            guard let date = asset.creationDate else { continue }
            let ratio = (asset.pixelHeight > 0) ? Double(asset.pixelWidth) / Double(asset.pixelHeight) : 1.0
            
            if let prevDate = lastDate, let prevRatio = lastRatio {
                let timeDiff = abs(date.timeIntervalSince(prevDate))
                let ratioDiff = abs(ratio - prevRatio)
                let isBurstAsset = asset.representsBurst || (asset.burstIdentifier != nil)
                
                // Similar photo condition: Shot taken within 8s AND matching aspect ratio (±12%) OR burst photo
                if (timeDiff <= 8.0 && ratioDiff <= 0.12) || isBurstAsset {
                    currentCluster.append(asset)
                } else {
                    if currentCluster.count >= 2 {
                        if let group = buildPhotoGroup(from: currentCluster) {
                            groups.append(group)
                        }
                    }
                    currentCluster = [asset]
                }
            } else {
                currentCluster = [asset]
            }
            lastDate = date
            lastRatio = ratio
        }
        
        if currentCluster.count >= 2 {
            if let group = buildPhotoGroup(from: currentCluster) {
                groups.append(group)
            }
        }
        
        var totalBytes: Int64 = 0
        for group in groups {
            totalBytes += group.selectedBytes
        }
        
        self.photoGroups = groups
        self.totalSimilarBytes = totalBytes
    }
    
    private func buildPhotoGroup(from assets: [PHAsset]) -> PhotoGroup? {
        guard assets.count >= 2 else { return nil }
        
        var items: [PhotoAssetItem] = []
        var isBurst = false
        
        for asset in assets {
            if asset.representsBurst || asset.burstIdentifier != nil {
                isBurst = true
            }
            let size = getFileSize(for: asset)
            let item = PhotoAssetItem(
                id: asset.localIdentifier,
                asset: asset,
                fileSize: size,
                creationDate: asset.creationDate,
                pixelWidth: asset.pixelWidth,
                pixelHeight: asset.pixelHeight,
                isSelected: false,
                isBest: false
            )
            items.append(item)
        }
        
        // Pick best item (highest resolution + size)
        guard let bestIndex = items.indices.max(by: {
            let area0 = items[$0].pixelWidth * items[$0].pixelHeight
            let area1 = items[$1].pixelWidth * items[$1].pixelHeight
            if area0 == area1 {
                return items[$0].fileSize < items[$1].fileSize
            }
            return area0 < area1
        }) else { return nil }
        
        for idx in items.indices {
            if idx == bestIndex {
                items[idx].isBest = true
                items[idx].isSelected = false // Retain best photo!
            } else {
                items[idx].isBest = false
                items[idx].isSelected = true // Pre-select duplicate items for cleanup
            }
        }
        
        let dateStr: String
        if let firstDate = items.first?.creationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            dateStr = formatter.string(from: firstDate)
        } else {
            dateStr = "Similar Group"
        }
        
        let groupTitle = isBurst ? "Burst Shot Series (\(items.count) shots)" : "Identical Scene • \(dateStr)"
        return PhotoGroup(title: groupTitle, items: items)
    }
    
    // MARK: - Blurry Photos Scanner
    func scanBlurryPhotos() async {
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 100
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var blurryItems: [PhotoAssetItem] = []
        var totalBytes: Int64 = 0
        
        result.enumerateObjects { asset, _, _ in
            let size = self.getFileSize(for: asset)
            if asset.pixelWidth < 600 || asset.pixelHeight < 600 {
                let item = PhotoAssetItem(
                    id: asset.localIdentifier,
                    asset: asset,
                    fileSize: size,
                    creationDate: asset.creationDate,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    isSelected: false,
                    isBest: false,
                    sharpnessScore: 0.3
                )
                blurryItems.append(item)
                totalBytes += size
            }
        }
        
        self.blurryPhotos = blurryItems
        self.totalBlurryBytes = totalBytes
    }
    
    // MARK: - File Size Helper
    func getFileSize(for asset: PHAsset) -> Int64 {
        if let cached = assetSizeCache[asset.localIdentifier] {
            return cached
        }
        
        let resources = PHAssetResource.assetResources(for: asset)
        var totalSize: Int64 = 0
        for resource in resources {
            if let unsignedSize = resource.value(forKey: "fileSize") as? Int64 {
                totalSize += unsignedSize
            }
        }
        
        if totalSize == 0 {
            if asset.mediaType == .video {
                totalSize = Int64(asset.duration * 2_500_000)
            } else {
                totalSize = Int64(asset.pixelWidth * asset.pixelHeight * 3 / 8)
            }
        }
        
        assetSizeCache[asset.localIdentifier] = totalSize
        return totalSize
    }
}
