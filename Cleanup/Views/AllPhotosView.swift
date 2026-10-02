import SwiftUI
import Photos

struct AllPhotosView: View {
    @ObservedObject var scanner: PhotoLibraryScanner
    @ObservedObject var cleaner: MediaCleaner
    @Binding var isTabBarVisible: Bool
    var onBack: (() -> Void)? = nil
    @StateObject private var vaultManager = VaultManager()
    
    @State private var selectedAssetIDs: Set<String> = []
    @State private var previewIndex: Int? = nil
    @State private var showReviewModal: Bool = false
    @State private var showCompletionScreen: Bool = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var isSortAscending: Bool = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var sortedPhotos: [PhotoAssetItem] {
        if isSortAscending {
            return scanner.allPhotos.sorted { $0.fileSize < $1.fileSize }
        } else {
            return scanner.allPhotos
        }
    }
    
    var selectedItems: [PhotoAssetItem] {
        sortedPhotos.filter { selectedAssetIDs.contains($0.id) }
    }
    
    var selectedBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.fileSize }
    }
    
    var allSelected: Bool {
        !sortedPhotos.isEmpty && selectedAssetIDs.count == sortedPhotos.count
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
                            Text("All Photos")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 6) {
                                Text("\(scanner.allPhotos.count) items • \(StorageManager.formatBytes(scanner.totalAllPhotosBytes))")
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
                                    selectedAssetIDs.removeAll()
                                } else {
                                    selectedAssetIDs = Set(sortedPhotos.map { $0.id })
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
                
                if scanner.isScanning {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading Photo Library...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else if scanner.allPhotos.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "photo.stack")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Photos Found")
                            .font(.headline)
                        Spacer()
                    }
                } else {
                    // Pixel-Perfect Square Photos Grid
                    ScrollView {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: proxy.frame(in: .named("allPhotosScroll")).minY
                            )
                        }
                        .frame(height: 0)
                        
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(Array(sortedPhotos.enumerated()), id: \.element.id) { index, item in
                                ZStack(alignment: .bottomTrailing) {
                                    Color.clear
                                        .aspectRatio(1.0, contentMode: .fit)
                                        .overlay(
                                            PHAssetImageView(asset: item.asset, targetSize: CGSize(width: 250, height: 250), contentMode: .fill)
                                        )
                                        .clipped()
                                    
                                    Rectangle()
                                        .fill(Color.black.opacity(selectedAssetIDs.contains(item.id) ? 0.35 : 0.0))
                                    
                                    Image(systemName: selectedAssetIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(selectedAssetIDs.contains(item.id) ? Color(red: 0.13, green: 0.77, blue: 0.36) : .white.opacity(0.85))
                                        .padding(6)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedAssetIDs.contains(item.id) {
                                        selectedAssetIDs.remove(item.id)
                                    } else {
                                        selectedAssetIDs.insert(item.id)
                                    }
                                }
                                .onLongPressGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        previewIndex = index
                                    }
                                }
                            }
                        }
                        .padding(.bottom, selectedAssetIDs.isEmpty ? 90 : 150)
                    }
                    .coordinateSpace(name: "allPhotosScroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { currentOffset in
                        guard previewIndex == nil else { return }
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
            if !selectedAssetIDs.isEmpty {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(selectedAssetIDs.count) Selected")
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
            
            // Full Screen Swipable Gallery Modal
            if let index = previewIndex {
                ImagePreviewGalleryModal(
                    items: sortedPhotos,
                    selectedIndex: index,
                    cleaner: cleaner,
                    vaultManager: vaultManager,
                    onPhotosChanged: {
                        await scanner.scanAllPhotos()
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
        .onChange(of: previewIndex) { newIndex in
            withAnimation(.easeInOut(duration: 0.25)) {
                isTabBarVisible = (newIndex == nil)
            }
        }
        .sheet(isPresented: $showReviewModal) {
            ReviewDeleteView(
                similarPhotos: selectedItems,
                screenshots: [],
                largeVideos: [],
                blurryPhotos: [],
                contacts: [],
                onConfirmDelete: {
                    Task {
                        let success = await cleaner.deleteAssets(selectedItems)
                        if success {
                            await scanner.scanAllPhotos()
                            selectedAssetIDs.removeAll()
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
