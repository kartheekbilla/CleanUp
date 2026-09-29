import SwiftUI
import Photos

struct SwipeCleanerView: View {
    @ObservedObject var scanner: PhotoLibraryScanner
    @ObservedObject var cleaner: MediaCleaner
    
    @State private var itemsToClean: [PhotoAssetItem] = []
    @State private var deleteQueue: [PhotoAssetItem] = []
    @State private var keepCount: Int = 0
    @State private var dragOffset: CGSize = .zero
    @State private var showReviewModal: Bool = false
    @State private var showCompletionScreen: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            if itemsToClean.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.teal)
                    Text("All Photos Reviewed!")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("You kept \(keepCount) photos and queued \(deleteQueue.count) for deletion.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if !deleteQueue.isEmpty {
                        Button(action: { showReviewModal = true }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Review & Delete (\(StorageManager.formatBytes(deleteQueue.reduce(0) { $0 + $1.fileSize })))")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 32)
                    }
                    Spacer()
                }
            } else {
                // Header Info
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Swipe Mode")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Swipe Left to Delete • Right to Keep")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    Spacer()
                    Text("\(itemsToClean.count) left")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.teal.opacity(0.15)))
                        .foregroundColor(.teal)
                }
                .padding(.horizontal)
                .padding(.top, 4)
                
                Spacer(minLength: 10)
                
                // Card Stack Container (Perfectly Aligned 3:4 Portrait Aspect)
                ZStack {
                    ForEach(Array(itemsToClean.prefix(3).reversed().enumerated()), id: \.element.id) { index, item in
                        let isTop = index == (min(itemsToClean.count, 3) - 1)
                        let scaleOffset = CGFloat(2 - index) * 0.04
                        let yOffset = CGFloat(2 - index) * 10.0
                        
                        SwipeCardView(item: item)
                            .scaleEffect(isTop ? 1.0 : (1.0 - scaleOffset))
                            .offset(y: isTop ? dragOffset.height * 0.2 : yOffset)
                            .offset(x: isTop ? dragOffset.width : 0)
                            .rotationEffect(.degrees(isTop ? Double(dragOffset.width / 15) : 0))
                            .gesture(
                                isTop ? DragGesture()
                                    .onChanged { gesture in
                                        dragOffset = gesture.translation
                                    }
                                    .onEnded { gesture in
                                        if gesture.translation.width < -100 {
                                            swipeLeft(item: item)
                                        } else if gesture.translation.width > 100 {
                                            swipeRight(item: item)
                                        } else {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                dragOffset = .zero
                                            }
                                        }
                                    } : nil
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                
                Spacer(minLength: 10)
                
                // Action Buttons Aligned Above Glassy Tab Bar
                HStack(spacing: 50) {
                    Button(action: {
                        if let top = itemsToClean.first {
                            swipeLeft(item: top)
                        }
                    }) {
                        Circle()
                            .fill(Color.red.opacity(0.12))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            )
                            .overlay(Circle().stroke(Color.red.opacity(0.3), lineWidth: 1))
                    }
                    
                    Button(action: {
                        if let top = itemsToClean.first {
                            swipeRight(item: top)
                        }
                    }) {
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            )
                            .overlay(Circle().stroke(Color.green.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(.bottom, 80)
            }
        }
        .navigationTitle("Swipe Cleaner")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadItems()
        }
        .sheet(isPresented: $showReviewModal) {
            ReviewDeleteView(
                similarPhotos: deleteQueue,
                screenshots: [],
                largeVideos: [],
                blurryPhotos: [],
                contacts: [],
                onConfirmDelete: {
                    Task {
                        let success = await cleaner.deleteAssets(deleteQueue)
                        if success {
                            deleteQueue.removeAll()
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
    
    private func loadItems() {
        var all: [PhotoAssetItem] = []
        for group in scanner.photoGroups {
            all.append(contentsOf: group.items)
        }
        if all.isEmpty {
            all = scanner.screenshots
        }
        if all.isEmpty {
            all = scanner.allPhotos
        }
        itemsToClean = Array(all.prefix(30))
    }
    
    private func swipeLeft(item: PhotoAssetItem) {
        withAnimation(.easeOut(duration: 0.25)) {
            deleteQueue.append(item)
            itemsToClean.removeAll { $0.id == item.id }
            dragOffset = .zero
        }
    }
    
    private func swipeRight(item: PhotoAssetItem) {
        withAnimation(.easeOut(duration: 0.25)) {
            keepCount += 1
            itemsToClean.removeAll { $0.id == item.id }
            dragOffset = .zero
        }
    }
}

struct SwipeCardView: View {
    let item: PhotoAssetItem
    
    var body: some View {
        Color.clear
            .aspectRatio(0.72, contentMode: .fit)
            .overlay(
                ZStack(alignment: .bottom) {
                    PHAssetImageView(asset: item.asset, targetSize: CGSize(width: 500, height: 700), contentMode: .fill)
                    
                    LinearGradient(
                        colors: [.black.opacity(0.85), .black.opacity(0.3), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 100)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.formattedSize)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("\(item.pixelWidth) × \(item.pixelHeight)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                    }
                    .padding(16)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .liquidGlassCard(cornerRadius: 28, highlightOpacity: 0.3)
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
    }
}
