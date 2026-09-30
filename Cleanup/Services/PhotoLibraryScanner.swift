import Foundation
import Photos
import UIKit
import CoreImage
import Combine

// MARK: - Disjoint-Set Union (Union-Find) Data Structure
struct DisjointSet {
    private var parent: [Int]
    
    init(size: Int) {
        parent = Array(0..<size)
    }
    
    mutating func find(_ i: Int) -> Int {
        if parent[i] == i {
            return i
        }
        parent[i] = find(parent[i])
        return parent[i]
    }
    
    mutating func union(_ i: Int, _ j: Int) {
        let rootI = find(i)
        let rootJ = find(j)
        if rootI != rootJ {
            parent[rootI] = rootJ
        }
    }
}

// MARK: - Perceptual Visual Hashing Engine (dHash & Color Fingerprinting)
final class PerceptualHashEngine {
    struct FeatureVector {
        let asset: PHAsset
        let dHash: UInt64
        let colorAvg: (r: UInt8, g: UInt8, b: UInt8)
    }
    
    static func extractFeatureVector(for asset: PHAsset) async -> FeatureVector? {
        guard let thumbnail = await requestThumbnail(for: asset, targetSize: CGSize(width: 32, height: 32)) else {
            return nil
        }
        guard let dHash = computeDHash(for: thumbnail) else { return nil }
        let color = computeAverageColor(for: thumbnail)
        return FeatureVector(asset: asset, dHash: dHash, colorAvg: color)
    }
    
    private static func requestThumbnail(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isSynchronous = false
            options.isNetworkAccessAllowed = false
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    // Difference Hashing (dHash): 9x8 grayscale downsampling -> 64-bit structural hash
    private static func computeDHash(for image: UIImage) -> UInt64? {
        guard let cgImage = image.cgImage else { return nil }
        let width = 9
        let height = 8
        var rawBytes = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        guard let context = CGContext(
            data: &rawBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var hash: UInt64 = 0
        var bitIndex = 0
        for row in 0..<8 {
            for col in 0..<8 {
                let left = rawBytes[row * 9 + col]
                let right = rawBytes[row * 9 + col + 1]
                if left > right {
                    hash |= (1 << (63 - bitIndex))
                }
                bitIndex += 1
            }
        }
        return hash
    }
    
    // 1x1 Downsampled Average Color Fingerprint
    private static func computeAverageColor(for image: UIImage) -> (r: UInt8, g: UInt8, b: UInt8) {
        guard let cgImage = image.cgImage else { return (128, 128, 128) }
        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) {
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return (pixel[0], pixel[1], pixel[2])
        }
        return (128, 128, 128)
    }
    
    static func areVisuallySimilar(_ a: FeatureVector, _ b: FeatureVector) -> Bool {
        // 1. Bitwise XOR popcount Hamming distance (0..64)
        let bitDistance = (a.dHash ^ b.dHash).nonzeroBitCount
        
        // 2. Color Euclidean Distance
        let dr = Int(a.colorAvg.r) - Int(b.colorAvg.r)
        let dg = Int(a.colorAvg.g) - Int(b.colorAvg.g)
        let db = Int(a.colorAvg.b) - Int(b.colorAvg.b)
        let colorDist = sqrt(Double(dr*dr + dg*dg + db*db))
        
        // 3. Aspect ratio difference
        let ratioA = Double(a.asset.pixelWidth) / Double(max(a.asset.pixelHeight, 1))
        let ratioB = Double(b.asset.pixelWidth) / Double(max(b.asset.pixelHeight, 1))
        let ratioDiff = abs(ratioA - ratioB)
        
        // High confidence similarity threshold:
        // Hamming distance <= 12 bits (out of 64, ~81%+ structural match) AND color distance <= 80 AND aspect ratio diff <= 0.15
        return bitDistance <= 12 && colorDist <= 80.0 && ratioDiff <= 0.15
    }
}

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
    
    // MARK: - Highly Efficient Multi-Stage Visual Perceptual Similarity Scanner
    func scanSimilarPhotos() async {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d AND (mediaSubtype & %d) == 0", PHAssetMediaType.image.rawValue, PHAssetMediaSubtype.photoScreenshot.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var allAssets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            allAssets.append(asset)
        }
        
        guard !allAssets.isEmpty else {
            self.photoGroups = []
            self.totalSimilarBytes = 0
            return
        }
        
        // Stage 1: Candidate Time-Window Pre-Filtering (Photos taken within 60 seconds)
        var candidateBlocks: [[PHAsset]] = []
        var currentBlock: [PHAsset] = []
        var lastDate: Date? = nil
        
        for asset in allAssets {
            guard let date = asset.creationDate else { continue }
            if let prev = lastDate {
                if abs(date.timeIntervalSince(prev)) <= 60.0 {
                    currentBlock.append(asset)
                } else {
                    if currentBlock.count >= 2 {
                        candidateBlocks.append(currentBlock)
                    }
                    currentBlock = [asset]
                }
            } else {
                currentBlock = [asset]
            }
            lastDate = date
        }
        if currentBlock.count >= 2 {
            candidateBlocks.append(currentBlock)
        }
        
        var groups: [PhotoGroup] = []
        
        // Stage 2 & 3: Perceptual Hashing & Transitive Union-Find Graph Clustering
        for block in candidateBlocks {
            let isBurstBlock = block.contains { $0.representsBurst || $0.burstIdentifier != nil }
            
            if isBurstBlock {
                if let group = buildPhotoGroup(from: block) {
                    groups.append(group)
                }
                continue
            }
            
            var featureVectors: [PerceptualHashEngine.FeatureVector] = []
            for asset in block {
                if let fv = await PerceptualHashEngine.extractFeatureVector(for: asset) {
                    featureVectors.append(fv)
                }
            }
            
            guard featureVectors.count >= 2 else { continue }
            
            var dsu = DisjointSet(size: featureVectors.count)
            
            for i in 0..<featureVectors.count {
                for j in (i+1)..<featureVectors.count {
                    let fvI = featureVectors[i]
                    let fvJ = featureVectors[j]
                    
                    if let dateI = fvI.asset.creationDate, let dateJ = fvJ.asset.creationDate {
                        let timeDiff = abs(dateI.timeIntervalSince(dateJ))
                        if timeDiff <= 60.0 {
                            if PerceptualHashEngine.areVisuallySimilar(fvI, fvJ) {
                                dsu.union(i, j)
                            }
                        }
                    }
                }
            }
            
            var clusters: [Int: [PHAsset]] = [:]
            for i in 0..<featureVectors.count {
                let root = dsu.find(i)
                clusters[root, default: []].append(featureVectors[i].asset)
            }
            
            for (_, assets) in clusters {
                if assets.count >= 2 {
                    if let group = buildPhotoGroup(from: assets) {
                        groups.append(group)
                    }
                }
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
