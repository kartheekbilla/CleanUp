import SwiftUI
import Photos
import AVFoundation

enum TargetVideoQuality: String, CaseIterable, Identifiable {
    case small = "480p Small Size"
    case balanced = "720p HD Balanced"
    case high = "1080p High Quality"
    
    var id: String { rawValue }
    
    var avPreset: String {
        switch self {
        case .small: return AVAssetExportPreset640x480
        case .balanced: return AVAssetExportPreset1280x720
        case .high: return AVAssetExportPreset1920x1080
        }
    }
    
    var reductionRatio: Double {
        switch self {
        case .small: return 0.30 // ~70% space saved
        case .balanced: return 0.50 // ~50% space saved
        case .high: return 0.75 // ~25% space saved
        }
    }
    
    var description: String {
        switch self {
        case .small: return "Maximum space saved (~70% reduction). Ideal for sharing."
        case .balanced: return "Recommended balance (~50% reduction). Crisp HD quality."
        case .high: return "Minimal compression (~25% reduction). Preserves fine details."
        }
    }
}

struct VideoCompressorView: View {
    @ObservedObject var scanner: PhotoLibraryScanner
    @StateObject private var compressor = VideoCompressorService()
    
    @State private var selectedQuality: TargetVideoQuality = .balanced
    @State private var showCompletionScreen: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            if scanner.largeVideos.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "arrow.down.right.and.arrow.up.left.square")
                        .font(.system(size: 50))
                        .foregroundColor(.indigo)
                    Text("No Videos Available to Compress")
                        .font(.headline)
                    Text("Scan your photo library to find videos.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                VStack(spacing: 14) {
                    // Target Quality Selector
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Select Target Compression Quality")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        
                        Picker("Target Quality", selection: $selectedQuality) {
                            ForEach(TargetVideoQuality.allCases) { quality in
                                Text(quality.rawValue).tag(quality)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(.indigo)
                        
                        Text(selectedQuality.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .liquidGlassCard(cornerRadius: 18)
                    .padding(.horizontal)
                }
                
                // Flat Single Video List
                List(scanner.largeVideos) { item in
                    CompressorVideoRowView(
                        item: item,
                        targetQuality: selectedQuality,
                        isCompressing: compressor.isCompressing
                    ) {
                        compressVideo(item)
                    }
                }
                .listStyle(.plain)
                .padding(.bottom, 75)
            }
        }
        .navigationTitle("Video Compressor")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if compressor.isCompressing {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        VStack(spacing: 6) {
                            Text("Compressing to \(selectedQuality.rawValue)")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(compressor.statusMessage)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        
                        ProgressView(value: Double(compressor.progress))
                            .tint(.indigo)
                            .frame(width: 180)
                    }
                    .padding(28)
                    .liquidGlassCard(cornerRadius: 24)
                }
            }
        }
        .fullScreenCover(isPresented: $showCompletionScreen) {
            CompletionView(
                freedBytes: compressor.savedBytes,
                deletedCount: 1,
                onDone: {
                    showCompletionScreen = false
                    Task {
                        await scanner.scanVideos()
                    }
                }
            )
        }
    }
    
    private func compressVideo(_ item: PhotoAssetItem) {
        Task {
            if let _ = await compressor.compressVideo(asset: item.asset, targetQuality: selectedQuality.avPreset) {
                showCompletionScreen = true
            }
        }
    }
}

struct CompressorVideoRowView: View {
    let item: PhotoAssetItem
    let targetQuality: TargetVideoQuality
    let isCompressing: Bool
    let onCompress: () -> Void
    
    var estimatedSize: Int64 {
        Int64(Double(item.fileSize) * targetQuality.reductionRatio)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            PHAssetImageView(asset: item.asset, targetSize: CGSize(width: 120, height: 120))
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.formattedSize)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Text("Est: \(StorageManager.formatBytes(estimatedSize))")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.indigo)
                    Text("(\(item.pixelWidth)×\(item.pixelHeight))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Compress", action: onCompress)
                .font(.callout)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(Color.indigo)
                )
                .disabled(isCompressing)
        }
        .padding(.vertical, 6)
    }
}
