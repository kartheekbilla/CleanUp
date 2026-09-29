import SwiftUI

struct UtilitiesSessionView: View {
    @ObservedObject var scanner: PhotoLibraryScanner
    @ObservedObject var cleaner: MediaCleaner
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Banner
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.indigo.opacity(0.18))
                                .frame(width: 48, height: 48)
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundColor(.indigo)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Smart Utilities")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("Advanced space optimization & private protection.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .liquidGlassCard(cornerRadius: 22)
                    .padding(.horizontal)
                    
                    // Utility Session Navigation Cards
                    NavigationLink(destination: VideoCompressorView(scanner: scanner)) {
                        CategoryCardView(
                            category: .videoCompressor,
                            count: scanner.largeVideos.count,
                            formattedBytes: "",
                            subtitle: "Compress 4K/1080p videos to 720p without loss"
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    
                    NavigationLink(destination: SwipeCleanerView(scanner: scanner, cleaner: cleaner)) {
                        CategoryCardView(
                            category: .swipeCleaner,
                            count: 0,
                            formattedBytes: "",
                            subtitle: "Tinder-style card swipe for rapid photo review"
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    
                    NavigationLink(destination: PrivateVaultView()) {
                        CategoryCardView(
                            category: .privateVault,
                            count: 0,
                            formattedBytes: "",
                            subtitle: "Face ID protected locker for private photos & docs"
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .padding(.bottom, 75)
            }
            .navigationTitle("Smart Utilities")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
