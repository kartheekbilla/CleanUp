import SwiftUI
import Photos

struct ScreenshotsView: View {
    @ObservedObject var scanner: PhotoLibraryScanner
    @ObservedObject var cleaner: MediaCleaner
    @Binding var isTabBarVisible: Bool
    @StateObject private var vaultManager = VaultManager()
    
    @State private var selectedIDs: Set<String> = []
    @State private var previewIndex: Int? = nil
    @State private var showReviewModal: Bool = false
    @State private var showCompletionScreen: Bool = false
    @State private var lastScrollOffset: CGFloat = 0
    
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var selectedAssets: [PhotoAssetItem] {
        scanner.screenshots.filter { selectedIDs.contains($0.id) }
    }
    
    var selectedBytes: Int64 {
        selectedAssets.reduce(0) { $0 + $1.fileSize }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if scanner.screenshots.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "iphone.gen3")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Screenshots Found")
                            .font(.headline)
                        Spacer()
                    }
                } else {
                    // Top Bar Select Controls
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(scanner.screenshots.count) Screenshots")
                                .font(.headline)
                            Text("Total size: \(StorageManager.formatBytes(scanner.totalScreenshotBytes)) • Swipe gallery mode")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(selectedIDs.count == scanner.screenshots.count ? "Deselect All" : "Select All") {
                            if selectedIDs.count == scanner.screenshots.count {
                                selectedIDs.removeAll()
                            } else {
                                selectedIDs = Set(scanner.screenshots.map { $0.id })
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    }
                    .padding()
                    
                    ScrollView {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: proxy.frame(in: .named("screenshotsScroll")).minY
                            )
                        }
                        .frame(height: 0)
                        
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(Array(scanner.screenshots.enumerated()), id: \.element.id) { index, item in
                                ZStack(alignment: .topTrailing) {
                                    Color.clear
                                        .frame(height: 180)
                                        .overlay(
                                            PHAssetImageView(asset: item.asset, targetSize: CGSize(width: 250, height: 400), contentMode: .fill)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(selectedIDs.contains(item.id) ? Color.purple : Color.clear, lineWidth: 3)
                                        )
                                    
                                    Button(action: {
                                        if selectedIDs.contains(item.id) {
                                            selectedIDs.remove(item.id)
                                        } else {
                                            selectedIDs.insert(item.id)
                                        }
                                    }) {
                                        Image(systemName: selectedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 22))
                                            .foregroundColor(selectedIDs.contains(item.id) ? .purple : .white.opacity(0.85))
                                            .shadow(color: Color.black.opacity(0.3), radius: 2)
                                            .padding(6)
                                    }
                                    
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Text(item.formattedSize)
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.black.opacity(0.65))
                                                .cornerRadius(4)
                                            Spacer()
                                        }
                                        .padding(6)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedIDs.contains(item.id) {
                                        selectedIDs.remove(item.id)
                                    } else {
                                        selectedIDs.insert(item.id)
                                    }
                                }
                                .onLongPressGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        previewIndex = index
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, selectedIDs.isEmpty ? 90 : 160)
                    }
                    .coordinateSpace(name: "screenshotsScroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { currentOffset in
                        guard previewIndex == nil else { return }
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
            
            // Floating Delete Action Bar
            if !selectedIDs.isEmpty {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(selectedIDs.count) Screenshots Selected")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Reclaim \(StorageManager.formatBytes(selectedBytes))")
                            .font(.caption)
                            .foregroundColor(.purple)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    Button(action: { showReviewModal = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                            Text("Clean Selected")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.purple)
                                .shadow(color: Color.purple.opacity(0.4), radius: 8, x: 0, y: 4)
                        )
                    }
                }
                .padding(16)
                .liquidGlassCard(cornerRadius: 26, highlightOpacity: 0.4)
                .padding(.horizontal, 16)
                .padding(.bottom, isTabBarVisible ? 82 : 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Full Screen Swipable Gallery Modal
            if let index = previewIndex {
                ImagePreviewGalleryModal(
                    items: scanner.screenshots,
                    selectedIndex: index,
                    cleaner: cleaner,
                    vaultManager: vaultManager,
                    onPhotosChanged: {
                        await scanner.scanScreenshots()
                    },
                    onDismiss: {
                        withAnimation {
                            previewIndex = nil
                        }
                    }
                )
                .ignoresSafeArea()
            }
        }
        .navigationTitle("Screenshots")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: previewIndex) { newIndex in
            withAnimation(.easeInOut(duration: 0.25)) {
                isTabBarVisible = (newIndex == nil)
            }
        }
        .sheet(isPresented: $showReviewModal) {
            ReviewDeleteView(
                similarPhotos: [],
                screenshots: selectedAssets,
                largeVideos: [],
                blurryPhotos: [],
                contacts: [],
                onConfirmDelete: {
                    Task {
                        let success = await cleaner.deleteAssets(selectedAssets)
                        if success {
                            await scanner.scanScreenshots()
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
}
