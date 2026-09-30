import SwiftUI

struct ContentView: View {
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var scanner = PhotoLibraryScanner()
    @StateObject private var contactScanner = ContactScanner()
    @StateObject private var cleaner = MediaCleaner()
    
    @State private var selectedTab: AppTab = .dashboard
    @State private var mediaSubFilter: MediaSubFilter = .similar
    @State private var isTabBarVisible: Bool = true
    @AppStorage("userThemePreference") private var selectedThemeRaw: String = ThemeOption.system.rawValue
    
    var preferredColorScheme: ColorScheme? {
        ThemeOption(rawValue: selectedThemeRaw)?.colorScheme
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background Subtle Liquid Gradient
            LinearGradient(
                colors: [
                    Color(UIColor.systemBackground),
                    Color.blue.opacity(0.03),
                    Color.purple.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Active Tab Content View
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView(
                        permissionManager: permissionManager,
                        scanner: scanner,
                        contactScanner: contactScanner,
                        cleaner: cleaner,
                        onNavigateToCategory: { category in
                            switch category {
                            case .similarPhotos:
                                mediaSubFilter = .similar
                                selectedTab = .media
                            case .screenshots:
                                mediaSubFilter = .screenshots
                                selectedTab = .media
                            case .largeVideos:
                                mediaSubFilter = .videos
                                selectedTab = .media
                            case .blurryPhotos:
                                mediaSubFilter = .blurry
                                selectedTab = .media
                            case .allPhotos:
                                mediaSubFilter = .all
                                selectedTab = .media
                            case .duplicateContacts:
                                selectedTab = .contacts
                            case .videoCompressor, .swipeCleaner, .privateVault:
                                selectedTab = .utilities
                            }
                        }
                    )
                case .media:
                    MediaSessionView(
                        scanner: scanner,
                        cleaner: cleaner,
                        selectedFilter: $mediaSubFilter,
                        isTabBarVisible: $isTabBarVisible
                    )
                case .contacts:
                    ContactsSessionView(scanner: contactScanner, cleaner: cleaner, permissionManager: permissionManager)
                case .utilities:
                    UtilitiesSessionView(scanner: scanner, cleaner: cleaner)
                case .extras:
                    ExtrasSessionView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Floating Liquid Glass Navigation Bar
            if isTabBarVisible || selectedTab != .media {
                GlassyTabBar(selectedTab: $selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: selectedTab) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isTabBarVisible = true
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }
}

#Preview {
    ContentView()
}
