import SwiftUI
import Photos

struct AllPhotosView: View {
    @ObservedObject var scanner: PhotoLibraryScanner
    @ObservedObject var cleaner: MediaCleaner
    @StateObject private var vaultManager = VaultManager()
    
    @State private var selectedAssetIDs: Set<String> = []
    @State private var previewIndex: Int? = nil
    @State private var showReviewModal: Bool = false
    @State private var showCompletionScreen: Bool = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var selectedItems: [PhotoAssetItem] {
        scanner.allPhotos.filter { selectedAssetIDs.contains($0.id) }
    }
    
    var selectedBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.fileSize }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
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
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Photos Found")
                            .font(.headline)
                        Spacer()
                    }
                } else {
                    // Toolbar Header Controls
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(scanner.allPhotos.count) Total Photos")
                                .font(.headline)
                            Text("Size: \(StorageManager.formatBytes(scanner.totalAllPhotosBytes)) • Swipe side-by-side gallery mode")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(selectedAssetIDs.count == scanner.allPhotos.count ? "Deselect All" : "Select All") {
                            if selectedAssetIDs.count == scanner.allPhotos.count {
                                selectedAssetIDs.removeAll()
                            } else {
                                selectedAssetIDs = Set(scanner.allPhotos.map { $0.id })
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    
                    // Pixel-Perfect Square Photos Grid
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(Array(scanner.allPhotos.enumerated()), id: \.element.id) { index, item in
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
                                        .foregroundColor(selectedAssetIDs.contains(item.id) ? .blue : .white.opacity(0.85))
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
                        .padding(.bottom, selectedAssetIDs.isEmpty ? 90 : 160)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Floating Glassy Delete Action Bar (Positioned Flush Above Glassy Tab Bar)
            if !selectedAssetIDs.isEmpty {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(selectedAssetIDs.count) Photos Selected")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Reclaim \(StorageManager.formatBytes(selectedBytes))")
                            .font(.caption)
                            .foregroundColor(.red)
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
                                .fill(Color.red)
                                .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)
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
                    items: scanner.allPhotos,
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
