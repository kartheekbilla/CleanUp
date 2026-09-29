import Foundation
import Photos
import AVFoundation
import Combine

@MainActor
class VideoCompressorService: ObservableObject {
    @Published var isCompressing: Bool = false
    @Published var progress: Float = 0.0
    @Published var statusMessage: String = ""
    @Published var compressedVideoURL: URL? = nil
    @Published var savedBytes: Int64 = 0
    
    func compressVideo(asset: PHAsset, targetQuality: String) async -> URL? {
        isCompressing = true
        progress = 0.1
        statusMessage = "Preparing original video asset..."
        
        let originalSize = getOriginalFileSize(for: asset)
        
        let imageManager = PHImageManager.default()
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        let avAsset: AVAsset? = await withCheckedContinuation { continuation in
            imageManager.requestAVAsset(forVideo: asset, options: options) { assetResult, _, _ in
                continuation.resume(returning: assetResult)
            }
        }
        
        guard let avAsset = avAsset else {
            isCompressing = false
            statusMessage = "Failed to load video asset."
            return nil
        }
        
        // Use the EXACT user-selected target preset
        let compatiblePresets = Set(AVAssetExportSession.exportPresets(compatibleWith: avAsset))
        let presetToUse = compatiblePresets.contains(targetQuality) ? targetQuality : AVAssetExportPresetMediumQuality
        
        statusMessage = "Compressing with \(presetNameFormatted(presetToUse))..."
        progress = 0.3
        
        let tempDir = FileManager.default.temporaryDirectory
        let outputFilename = "compressed_\(UUID().uuidString).mp4"
        let outputURL = tempDir.appendingPathComponent(outputFilename)
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: presetToUse) else {
            isCompressing = false
            statusMessage = "Cannot create export session for this video."
            return nil
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Progress Monitoring
        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            Task { @MainActor in
                if exportSession.status == .exporting {
                    self.progress = 0.3 + (exportSession.progress * 0.65)
                }
            }
        }
        
        let success: Bool = await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                continuation.resume(returning: exportSession.status == .completed)
            }
        }
        
        timer.invalidate()
        
        if success {
            let compressedSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
            
            // Save compressed video to Photos Library
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
            }) { _, _ in }
            
            let freed = max(0, originalSize - compressedSize)
            self.savedBytes = freed
            self.compressedVideoURL = outputURL
            self.progress = 1.0
            self.statusMessage = "Successfully compressed! (Saved \(StorageManager.formatBytes(freed)))"
            self.isCompressing = false
            return outputURL
        } else {
            self.isCompressing = false
            self.statusMessage = "Compression failed: \(exportSession.error?.localizedDescription ?? "Unknown error")"
            return nil
        }
    }
    
    private func presetNameFormatted(_ preset: String) -> String {
        switch preset {
        case AVAssetExportPreset1920x1080: return "1080p Full HD"
        case AVAssetExportPreset1280x720: return "720p HD Quality"
        case AVAssetExportPresetMediumQuality: return "Medium Quality"
        case AVAssetExportPreset640x480: return "480p SD Small Size"
        case AVAssetExportPresetLowQuality: return "Low Bitrate"
        default: return "Selected Quality"
        }
    }
    
    private func getOriginalFileSize(for asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        for res in resources {
            if let size = res.value(forKey: "fileSize") as? Int64, size > 0 {
                return size
            }
        }
        return Int64(asset.duration * 2_500_000)
    }
}
