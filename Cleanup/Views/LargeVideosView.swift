import SwiftUI
import Photos
import AVKit

struct LargeVideosView: View {
    @ObservedObject var scanner: PhotoLibraryScanner
    @ObservedObject var cleaner: MediaCleaner
    @Binding var isTabBarVisible: Bool
    
    @State private var selectedIDs: Set<String> = []
    @State private var previewAsset: PHAsset? = nil
    @State private var playerURL: URL? = nil
    @State private var showReviewModal: Bool = false
    @State private var showCompletionScreen: Bool = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var playerURLWrapper: URLIdentifiable? = nil
    
    var selectedAssets: [PhotoAssetItem] {
        scanner.largeVideos.filter { selectedIDs.contains($0.id) }
    }
    
    var selectedBytes: Int64 {
        selectedAssets.reduce(0) { $0 + $1.fileSize }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if scanner.largeVideos.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "film.stack")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Videos Found")
                            .font(.headline)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: proxy.frame(in: .named("videosScroll")).minY
                            )
                        }
                        .frame(height: 0)
                        
                        LazyVStack(spacing: 12) {
                            HStack {
                                Text("Sorted Largest to Smallest")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 4)
                            
                            ForEach(scanner.largeVideos) { item in
                                VideoRowView(
                                    item: item,
                                    isSelected: selectedIDs.contains(item.id),
                                    onToggle: {
                                        if selectedIDs.contains(item.id) {
                                            selectedIDs.remove(item.id)
                                        } else {
                                            selectedIDs.insert(item.id)
                                        }
                                    },
                                    onPreview: {
                                        playVideo(asset: item.asset)
                                    }
                                )
                                .padding(12)
                                .liquidGlassCard(cornerRadius: 16)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, selectedIDs.isEmpty ? 90 : 160)
                    }
                    .coordinateSpace(name: "videosScroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { currentOffset in
                        guard playerURLWrapper == nil else { return }
                        let delta = currentOffset - lastScrollOffset
                        if currentOffset > -15 {
                            if !isTabBarVisible {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isTabBarVisible = true
                                }
                            }
                        } else if delta < -12 {
                            if isTabBarVisible {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isTabBarVisible = false
                                }
                            }
                        } else if delta > 12 {
                            if !isTabBarVisible {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isTabBarVisible = true
                                }
                            }
                        }
                        lastScrollOffset = currentOffset
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Floating Clean Bar
            if !selectedIDs.isEmpty {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(selectedIDs.count) Videos Selected")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Reclaim \(StorageManager.formatBytes(selectedBytes))")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    Button(action: { showReviewModal = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                            Text("Clean Videos")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.orange)
                                .shadow(color: Color.orange.opacity(0.4), radius: 8, x: 0, y: 4)
                        )
                    }
                }
                .padding(16)
                .liquidGlassCard(cornerRadius: 26, highlightOpacity: 0.4)
                .padding(.horizontal, 16)
                .padding(.bottom, isTabBarVisible ? 82 : 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Large Videos")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: playerURLWrapper != nil) { isPlaying in
            withAnimation(.easeInOut(duration: 0.25)) {
                isTabBarVisible = !isPlaying
            }
        }
        .sheet(item: $playerURLWrapper) { wrapper in
            VideoPlayerSheet(url: wrapper.url)
        }
        .sheet(isPresented: $showReviewModal) {
            ReviewDeleteView(
                similarPhotos: [],
                screenshots: [],
                largeVideos: selectedAssets,
                blurryPhotos: [],
                contacts: [],
                onConfirmDelete: {
                    Task {
                        let success = await cleaner.deleteAssets(selectedAssets)
                        if success {
                            await scanner.scanVideos()
                            selectedIDs.removeAll()
                            showCompletionScreen = true
                        }
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showCompletionScreen) {
            CompletionView(
                freedBytes: cleaner.lastFreedBytes,
                deletedCount: cleaner.lastDeletedCount,
                onDone: { showCompletionScreen = false }
            )
        }
    }
    
    private func playVideo(asset: PHAsset) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            if let urlAsset = avAsset as? AVURLAsset {
                DispatchQueue.main.async {
                    self.playerURLWrapper = URLIdentifiable(url: urlAsset.url)
                }
            }
        }
    }
}

struct URLIdentifiable: Identifiable {
    let id = UUID()
    let url: URL
}

struct VideoPlayerSheet: View {
    let url: URL
    
    var body: some View {
        NavigationStack {
            VideoPlayer(player: AVPlayer(url: url))
                .edgesIgnoringSafeArea(.all)
                .navigationTitle("Preview Video")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct VideoRowView: View {
    let item: PhotoAssetItem
    let isSelected: Bool
    let onToggle: () -> Void
    let onPreview: () -> Void
    
    var durationText: String {
        let dur = Int(item.asset.duration)
        let mins = dur / 60
        let secs = dur % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .orange : .gray)
            }
            
            // Video Thumbnail
            ZStack {
                PHAssetImageView(asset: item.asset, targetSize: CGSize(width: 160, height: 160))
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                Button(action: onPreview) {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.formattedSize)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Label(durationText, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(item.pixelWidth)x\(item.pixelHeight)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
}
