import SwiftUI
import Photos

struct SimilarPhotosView: View {
    @ObservedObject var scanner: PhotoLibraryScanner
    @ObservedObject var cleaner: MediaCleaner
    @Binding var isTabBarVisible: Bool
    var onBack: (() -> Void)? = nil
    @StateObject private var vaultManager = VaultManager()
    
    @State private var selectedItems: Set<String> = []
    @State private var previewIndex: Int? = nil
    @State private var showReviewModal: Bool = false
    @State private var showCompletionScreen: Bool = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var isSortAscending: Bool = false
    
    var sortedGroups: [PhotoGroup] {
        if isSortAscending {
            return scanner.photoGroups.sorted { $0.items.count < $1.items.count }
        } else {
            return scanner.photoGroups.sorted { $0.items.count > $1.items.count }
        }
    }
    
    var allGroupedPhotos: [PhotoAssetItem] {
        sortedGroups.flatMap { $0.items }
    }
    
    var selectedPhotoAssets: [PhotoAssetItem] {
        allGroupedPhotos.filter { selectedItems.contains($0.id) }
    }
    
    var selectedBytes: Int64 {
        selectedPhotoAssets.reduce(0) { $0 + $1.fileSize }
    }
    
    var totalGroupedBytes: Int64 {
        allGroupedPhotos.reduce(0) { $0 + $1.fileSize }
    }
    
    var allSelected: Bool {
        !allGroupedPhotos.isEmpty && selectedItems.count == allGroupedPhotos.count
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
                            Text("Similars")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 6) {
                                Text("\(allGroupedPhotos.count) items • \(StorageManager.formatBytes(totalGroupedBytes))")
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
                                    selectedItems.removeAll()
                                } else {
                                    selectedItems = Set(allGroupedPhotos.map { $0.id })
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
                
                if scanner.photoGroups.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "sparkles")
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
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: proxy.frame(in: .named("similarScroll")).minY
                            )
                        }
                        .frame(height: 0)
                        
                        LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                            ForEach(sortedGroups) { group in
                                Section(
                                    header: GroupHeaderView(
                                        title: group.title,
                                        count: group.items.count,
                                        bytes: group.items.reduce(0) { $0 + $1.fileSize }
                                    )
                                ) {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 14) {
                                            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                                PhotoCardView(
                                                    item: item,
                                                    indexInGroup: index + 1,
                                                    totalInGroup: group.items.count,
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
                        .padding(.bottom, selectedItems.isEmpty ? 90 : 150)
                    }
                    .coordinateSpace(name: "similarScroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { currentOffset in
                        guard previewIndex == nil else { return }
                        let delta = currentOffset - lastScrollOffset
                        if currentOffset > -15 {
                            if !isTabBarVisible {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isTabBarVisible = true
                                }
                            }
                        } else if delta < -3 {
                            if isTabBarVisible {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isTabBarVisible = false
                                }
                            }
                        } else if delta > 3 {
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
            if !selectedItems.isEmpty {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(selectedItems.count) Selected")
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
        .onAppear {
            initSelections()
        }
        .onChange(of: previewIndex) { newIndex in
            withAnimation(.easeInOut(duration: 0.25)) {
                isTabBarVisible = (newIndex == nil)
            }
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
                    .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.36))
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
    let indexInGroup: Int
    let totalInGroup: Int
    let isSelected: Bool
    let onToggle: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(width: 170, height: 220)
                .overlay(
                    PHAssetImageView(asset: item.asset, targetSize: CGSize(width: 300, height: 400), contentMode: .fill)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isSelected ? Color(red: 0.13, green: 0.77, blue: 0.36) : Color.white.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                )
            
            // Item Metadata (Index & Size overlay)
            VStack {
                HStack {
                    if !item.isBest {
                        Text("\(indexInGroup) of \(totalInGroup)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.black.opacity(0.55)))
                            .padding(8)
                    }
                    Spacer()
                    
                    // Emerald Green Checkmark (Top Right)
                    Button(action: onToggle) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundColor(isSelected ? Color(red: 0.13, green: 0.77, blue: 0.36) : .white.opacity(0.85))
                            .shadow(color: Color.black.opacity(0.3), radius: 3)
                            .padding(8)
                    }
                }
                Spacer()
            }
            
            // Prominent "Best Shot" Banner anchored at the bottom
            if item.isBest {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.yellow)
                        Text("Best Shot")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.13, green: 0.77, blue: 0.36))
                }
                .clipShape(CornerRadiusShape(radius: 18, corners: [.bottomLeft, .bottomRight]))
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(item.formattedSize)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
                .padding(8)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.7), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .clipShape(CornerRadiusShape(radius: 18, corners: [.bottomLeft, .bottomRight]))
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

// Shape Helper for bottom-only rounded corners
struct CornerRadiusShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
