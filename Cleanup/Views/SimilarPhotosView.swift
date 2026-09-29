import SwiftUI
import Photos

struct SimilarPhotosView: View {
    @ObservedObject var scanner: PhotoLibraryScanner
    @ObservedObject var cleaner: MediaCleaner
    @StateObject private var vaultManager = VaultManager()
    
    @State private var selectedItems: Set<String> = []
    @State private var previewIndex: Int? = nil
    @State private var showReviewModal: Bool = false
    @State private var showCompletionScreen: Bool = false
    
    var allGroupedPhotos: [PhotoAssetItem] {
        scanner.photoGroups.flatMap { $0.items }
    }
    
    var selectedPhotoAssets: [PhotoAssetItem] {
        allGroupedPhotos.filter { selectedItems.contains($0.id) }
    }
    
    var selectedBytes: Int64 {
        selectedPhotoAssets.reduce(0) { $0 + $1.fileSize }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if scanner.photoGroups.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Similar Photos Found")
                            .font(.headline)
                        Text("Your photo library is nicely organized!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                            ForEach(scanner.photoGroups) { group in
                                Section(
                                    header: GroupHeaderView(
                                        title: group.title,
                                        count: group.items.count,
                                        bytes: group.items.reduce(0) { $0 + $1.fileSize }
                                    )
                                ) {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 14) {
                                            ForEach(group.items) { item in
                                                PhotoCardView(
                                                    item: item,
                                                    isSelected: selectedItems.contains(item.id),
                                                    onToggle: {
                                                        if selectedItems.contains(item.id) {
                                                            selectedItems.remove(item.id)
                                                        } else {
                                                            selectedItems.insert(item.id)
                                                        }
                                                    },
                                                    onLongPress: {
                                                        if let idx = allGroupedPhotos.firstIndex(where: { $0.id == item.id }) {
                                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                                                previewIndex = idx
                                                            }
                                                        }
                                                    }
                                                )
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                        .padding(.bottom, selectedItems.isEmpty ? 90 : 160)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Floating Clean Bar (Positioned Flush Above Glassy Tab Bar)
            if !selectedItems.isEmpty {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(selectedItems.count) Photos Selected")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Reclaim \(StorageManager.formatBytes(selectedBytes))")
                            .font(.caption)
                            .foregroundColor(.blue)
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
                                .fill(Color.blue)
                                .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                        )
                    }
                }
                .padding(16)
                .liquidGlassCard(cornerRadius: 26, highlightOpacity: 0.4)
                .padding(.horizontal, 16)
                .padding(.bottom, 82)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Full Screen Swipable Gallery Modal (With Lock to Vault 🔒)
            if let index = previewIndex {
                ImagePreviewGalleryModal(
                    items: allGroupedPhotos,
                    selectedIndex: index,
                    cleaner: cleaner,
                    vaultManager: vaultManager,
                    onPhotosChanged: {
                        await scanner.scanSimilarPhotos()
                        initSelections()
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
        .navigationTitle("Similar Photos")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            initSelections()
        }
        .sheet(isPresented: $showReviewModal) {
            ReviewDeleteView(
                similarPhotos: selectedPhotoAssets,
                screenshots: [],
                largeVideos: [],
                blurryPhotos: [],
                contacts: [],
                onConfirmDelete: {
                    Task {
                        let success = await cleaner.deleteAssets(selectedPhotoAssets)
                        if success {
                            await scanner.scanSimilarPhotos()
                            initSelections()
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
    
    private func initSelections() {
        var set = Set<String>()
        for group in scanner.photoGroups {
            for item in group.items {
                if item.isSelected {
                    set.insert(item.id)
                }
            }
        }
        selectedItems = set
    }
}

struct GroupHeaderView: View {
    let title: String
    let count: Int
    let bytes: Int64
    
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text("\(count) shots • \(StorageManager.formatBytes(bytes))")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Color(UIColor.systemBackground).opacity(0.92)
        )
    }
}

struct PhotoCardView: View {
    let item: PhotoAssetItem
    let isSelected: Bool
    let onToggle: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .frame(width: 160, height: 210)
                .overlay(
                    PHAssetImageView(asset: item.asset, targetSize: CGSize(width: 300, height: 400), contentMode: .fill)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isSelected ? Color.blue : Color.white.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                )
            
            // Bottom Info Gradient Overlay
            LinearGradient(
                colors: [.black.opacity(0.85), .black.opacity(0.2), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            
            // Item Metadata (Size & Resolution)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.formattedSize)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("\(item.pixelWidth) × \(item.pixelHeight)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(10)
            
            // Selection Checkmark (Top Right)
            VStack {
                HStack {
                    Spacer()
                    Button(action: onToggle) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundColor(isSelected ? .blue : .white.opacity(0.85))
                            .shadow(color: Color.black.opacity(0.3), radius: 3)
                            .padding(8)
                    }
                }
                Spacer()
            }
            
            // Best Photo Badge (Top Left)
            if item.isBest {
                VStack {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                            Text("Best Photo")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.yellow))
                        .padding(8)
                        
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
        .onLongPressGesture {
            onLongPress()
        }
    }
}
