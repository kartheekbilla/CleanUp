import SwiftUI

enum MediaSubFilter: String, CaseIterable, Identifiable {
    case all = "All Photos"
    case similar = "Similar Photos"
    case screenshots = "Screenshots"
    case videos = "Videos"
    case blurry = "Blurry Images"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .all: return "photo.stack"
        case .similar: return "sparkles"
        case .screenshots: return "iphone.gen3"
        case .videos: return "film.stack"
        case .blurry: return "eye.slash"
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .all:
            return [Color.blue, Color.cyan]
        case .similar:
            return [Color(red: 0.08, green: 0.65, blue: 0.45), Color(red: 0.13, green: 0.77, blue: 0.36)]
        case .screenshots:
            return [Color.purple, Color.indigo]
        case .videos:
            return [Color.orange, Color.red]
        case .blurry:
            return [Color.pink, Color.purple]
        }
    }
}

struct MediaSessionView: View {
    @ObservedObject var scanner: PhotoLibraryScanner
    @ObservedObject var cleaner: MediaCleaner
    @Binding var selectedFilter: MediaSubFilter?
    @Binding var isTabBarVisible: Bool
    
    @State private var lastScrollOffset: CGFloat = 0
    
    func getItemCount(for filter: MediaSubFilter) -> Int {
        switch filter {
        case .all: return scanner.allPhotos.count
        case .similar: return scanner.photoGroups.reduce(0) { $0 + $1.items.count }
        case .screenshots: return scanner.screenshots.count
        case .videos: return scanner.largeVideos.count
        case .blurry: return scanner.blurryPhotos.count
        }
    }
    
    func getFormattedSize(for filter: MediaSubFilter) -> String {
        let bytes: Int64
        switch filter {
        case .all: bytes = scanner.totalAllPhotosBytes
        case .similar: bytes = scanner.totalSimilarBytes
        case .screenshots: bytes = scanner.totalScreenshotBytes
        case .videos: bytes = scanner.totalVideoBytes
        case .blurry: bytes = scanner.totalBlurryBytes
        }
        return StorageManager.formatBytes(bytes)
    }
    
    var totalReclaimableBytes: Int64 {
        scanner.totalSimilarBytes + scanner.totalScreenshotBytes + scanner.totalVideoBytes + scanner.totalBlurryBytes
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let activeFilter = selectedFilter {
                    // Active Detail View with Back Button
                    switch activeFilter {
                    case .all:
                        AllPhotosView(
                            scanner: scanner,
                            cleaner: cleaner,
                            isTabBarVisible: $isTabBarVisible,
                            onBack: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedFilter = nil
                                }
                            }
                        )
                    case .similar:
                        SimilarPhotosView(
                            scanner: scanner,
                            cleaner: cleaner,
                            isTabBarVisible: $isTabBarVisible,
                            onBack: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedFilter = nil
                                }
                            }
                        )
                    case .screenshots:
                        ScreenshotsView(
                            scanner: scanner,
                            cleaner: cleaner,
                            isTabBarVisible: $isTabBarVisible,
                            onBack: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedFilter = nil
                                }
                            }
                        )
                    case .videos:
                        LargeVideosView(
                            scanner: scanner,
                            cleaner: cleaner,
                            isTabBarVisible: $isTabBarVisible,
                            onBack: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedFilter = nil
                                }
                            }
                        )
                    case .blurry:
                        BlurryPhotosView(
                            scanner: scanner,
                            cleaner: cleaner,
                            isTabBarVisible: $isTabBarVisible,
                            onBack: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedFilter = nil
                                }
                            }
                        )
                    }
                } else {
                    // Vertical Stack of Category Cards
                    ScrollView {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: proxy.frame(in: .named("mediaStackScroll")).minY
                            )
                        }
                        .frame(height: 0)
                        
                        VStack(alignment: .leading, spacing: 18) {
                            // Summary Banner
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.13, green: 0.77, blue: 0.36).opacity(0.15))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.36))
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Media Cleanup")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("Reclaim up to \(StorageManager.formatBytes(totalReclaimableBytes))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(18)
                            .liquidGlassCard(cornerRadius: 24)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            Text("Categories")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 4)
                            
                            // Vertical Stack of Cards
                            VStack(spacing: 12) {
                                ForEach(MediaSubFilter.allCases) { filter in
                                    MediaCategoryStackCard(
                                        icon: filter.iconName,
                                        title: filter.rawValue,
                                        count: getItemCount(for: filter),
                                        sizeText: getFormattedSize(for: filter),
                                        gradientColors: filter.gradientColors,
                                        action: {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                selectedFilter = filter
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 100)
                        }
                    }
                    .coordinateSpace(name: "mediaStackScroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { currentOffset in
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
            .navigationTitle(selectedFilter == nil ? "Media Clean" : "")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(selectedFilter != nil)
            .onChange(of: selectedFilter) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    isTabBarVisible = true
                }
            }
        }
    }
}

struct MediaCategoryStackCard: View {
    let icon: String
    let title: String
    let count: Int
    let sizeText: String
    let gradientColors: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon Container
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: gradientColors.first?.opacity(0.3) ?? Color.clear, radius: 6, x: 0, y: 3)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("\(count) items • \(sizeText)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(14)
            .liquidGlassCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
    }
}
