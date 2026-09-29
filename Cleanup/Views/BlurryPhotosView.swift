import SwiftUI
import Photos

struct BlurryPhotosView: View {
    @ObservedObject var scanner: PhotoLibraryScanner
    @ObservedObject var cleaner: MediaCleaner
    @StateObject private var vaultManager = VaultManager()
    
    @State private var selectedIDs: Set<String> = []
    @State private var previewIndex: Int? = nil
    @State private var showReviewModal: Bool = false
    @State private var showCompletionScreen: Bool = false
    
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var selectedAssets: [PhotoAssetItem] {
        scanner.blurryPhotos.filter { selectedIDs.contains($0.id) }
    }
    
    var selectedBytes: Int64 {
        selectedAssets.reduce(0) { $0 + $1.fileSize }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if scanner.blurryPhotos.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "eye.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Blurry Photos Detected")
                            .font(.headline)
                        Text("All your photos look crisp!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(scanner.blurryPhotos.count) Low Quality Photos")
                                .font(.headline)
                            Text("Total size: \(StorageManager.formatBytes(scanner.totalBlurryBytes)) • Swipe gallery mode")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(selectedIDs.count == scanner.blurryPhotos.count ? "Deselect All" : "Select All") {
                            if selectedIDs.count == scanner.blurryPhotos.count {
                                selectedIDs.removeAll()
                            } else {
                                selectedIDs = Set(scanner.blurryPhotos.map { $0.id })
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.pink)
                    }
                    .padding()
                    
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(Array(scanner.blurryPhotos.enumerated()), id: \.element.id) { index, item in
                                ZStack(alignment: .topTrailing) {
                                    Color.clear
                                        .frame(height: 120)
                                        .overlay(
                                            PHAssetImageView(asset: item.asset, targetSize: CGSize(width: 200, height: 200), contentMode: .fill)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(selectedIDs.contains(item.id) ? Color.pink : Color.clear, lineWidth: 3)
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
                                            .foregroundColor(selectedIDs.contains(item.id) ? .pink : .white.opacity(0.85))
                                            .shadow(color: Color.black.opacity(0.3), radius: 2)
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
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Floating Glassy Delete Action Bar
            if !selectedIDs.isEmpty {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(selectedIDs.count) Selected")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Reclaim \(StorageManager.formatBytes(selectedBytes))")
                            .font(.caption)
                            .foregroundColor(.pink)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    Button(action: { showReviewModal = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                            Text("Clean Blurry")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.pink)
                                .shadow(color: Color.pink.opacity(0.4), radius: 8, x: 0, y: 4)
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
                    items: scanner.blurryPhotos,
                    selectedIndex: index,
                    cleaner: cleaner,
                    vaultManager: vaultManager,
                    onPhotosChanged: {
                        await scanner.scanBlurryPhotos()
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
        .navigationTitle("Blurry Photos")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showReviewModal) {
            ReviewDeleteView(
                similarPhotos: [],
                screenshots: [],
                largeVideos: [],
                blurryPhotos: selectedAssets,
                contacts: [],
                onConfirmDelete: {
                    Task {
                        let success = await cleaner.deleteAssets(selectedAssets)
                        if success {
                            await scanner.scanBlurryPhotos()
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
