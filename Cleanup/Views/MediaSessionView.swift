import SwiftUI

enum MediaSubFilter: String, CaseIterable, Identifiable {
    case similar = "Similar"
    case screenshots = "Screenshots"
    case videos = "Videos"
    case blurry = "Blurry"
    case all = "All Photos"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .similar: return "photo.on.rectangle.angled"
        case .screenshots: return "iphone.gen3"
        case .videos: return "film.stack"
        case .blurry: return "eye.slash"
        case .all: return "photo.stack"
        }
    }
}

struct MediaSessionView: View {
    @ObservedObject var scanner: PhotoLibraryScanner
    @ObservedObject var cleaner: MediaCleaner
    @Binding var selectedFilter: MediaSubFilter
    @Binding var isTabBarVisible: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Glassy Horizontal Scroll Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MediaSubFilter.allCases) { filter in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    selectedFilter = filter
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: filter.iconName)
                                        .font(.caption)
                                    Text(filter.rawValue)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(selectedFilter == filter ? .white : .primary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                .background(
                                    Group {
                                        if selectedFilter == filter {
                                            Capsule()
                                                .fill(Color.blue)
                                                .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)
                                        } else {
                                            Capsule()
                                                .fill(Color.primary.opacity(0.06))
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .liquidGlassCard(cornerRadius: 30)
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 6)
                
                // Active Sub-Session View Content
                Group {
                    switch selectedFilter {
                    case .similar:
                        SimilarPhotosView(scanner: scanner, cleaner: cleaner, isTabBarVisible: $isTabBarVisible)
                    case .screenshots:
                        ScreenshotsView(scanner: scanner, cleaner: cleaner, isTabBarVisible: $isTabBarVisible)
                    case .videos:
                        LargeVideosView(scanner: scanner, cleaner: cleaner, isTabBarVisible: $isTabBarVisible)
                    case .blurry:
                        BlurryPhotosView(scanner: scanner, cleaner: cleaner, isTabBarVisible: $isTabBarVisible)
                    case .all:
                        AllPhotosView(scanner: scanner, cleaner: cleaner, isTabBarVisible: $isTabBarVisible)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Media Clean")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedFilter) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    isTabBarVisible = true
                }
            }
        }
    }
}
