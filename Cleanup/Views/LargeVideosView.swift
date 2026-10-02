import SwiftUI
import Photos
import AVKit

struct LargeVideosView: View {
    @ObservedObject var scanner: PhotoLibraryScanner
    @ObservedObject var cleaner: MediaCleaner
    @Binding var isTabBarVisible: Bool
    var onBack: (() -> Void)? = nil
    
    @State private var selectedIDs: Set<String> = []
    @State private var previewAsset: PHAsset? = nil
    @State private var playerURL: URL? = nil
    @State private var showReviewModal: Bool = false
    @State private var showCompletionScreen: Bool = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var playerURLWrapper: URLIdentifiable? = nil
    @State private var isSortAscending: Bool = false
    
    var sortedVideos: [PhotoAssetItem] {
        if isSortAscending {
            return scanner.largeVideos.sorted { $0.fileSize < $1.fileSize }
        } else {
            return scanner.largeVideos.sorted { $0.fileSize > $1.fileSize }
        }
    }
    
    var selectedAssets: [PhotoAssetItem] {
        sortedVideos.filter { selectedIDs.contains($0.id) }
    }
    
    var selectedBytes: Int64 {
        selectedAssets.reduce(0) { $0 + $1.fileSize }
    }
    
    var allSelected: Bool {
        !sortedVideos.isEmpty && selectedIDs.count == sortedVideos.count
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Category Header matching reference design
                VStack(spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        if let onBack = onBack {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(10)
                                    .background(
                                        Circle()
                                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                                            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                                    )
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Videos")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 6) {
                                Text("\(scanner.largeVideos.count) items • \(StorageManager.formatBytes(scanner.totalVideoBytes))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.36))
                                    Text("Ready to clean")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.36))
                                }
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button(action: {
                                if allSelected {
                                    selectedIDs.removeAll()
                                } else {
                                    selectedIDs = Set(sortedVideos.map { $0.id })
                                }
                            }) {
                                Text(allSelected ? "Deselect All" : "Select All")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.36))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(Color(red: 0.13, green: 0.77, blue: 0.36).opacity(0.15))
                                    )
                            }
                            
                            Button(action: {
                                withAnimation {
                                    isSortAscending.toggle()
                                }
                            }) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemBackground))
                
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
                            ForEach(sortedVideos) { item in
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
                        .padding(.top, 4)
                        .padding(.bottom, selectedIDs.isEmpty ? 90 : 150)
                    }
                    .coordinateSpace(name: "videosScroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { currentOffset in
                        guard playerURLWrapper == nil else { return }
                        let delta = currentOffset - lastScrollOffset
                        if currentOffset > -10 {
                            if !isTabBarVisible {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isTabBarVisible = true
                                }
                            }
                        } else if delta < -5 {
                            if isTabBarVisible {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isTabBarVisible = false
                                }
                            }
                        } else if delta > 5 {
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
            
            // Compact Floating Clean Action Bar
            if !selectedIDs.isEmpty {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(selectedIDs.count) Selected")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Reclaim \(StorageManager.formatBytes(selectedBytes))")
                            .font(.caption2)
                            .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.36))
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    Button(action: { showReviewModal = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                                .font(.caption)
                            Text("Delete")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.13, green: 0.77, blue: 0.36))
                                .shadow(color: Color(red: 0.13, green: 0.77, blue: 0.36).opacity(0.35), radius: 6, x: 0, y: 3)
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .liquidGlassCard(cornerRadius: 20, highlightOpacity: 0.4)
                .padding(.horizontal, 20)
                .padding(.bottom, isTabBarVisible ? 82 : 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
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
                    .foregroundColor(isSelected ? Color(red: 0.13, green: 0.77, blue: 0.36) : .gray)
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
