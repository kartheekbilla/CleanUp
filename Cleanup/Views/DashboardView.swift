import SwiftUI
import Photos

struct DashboardView: View {
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var scanner: PhotoLibraryScanner
    @ObservedObject var contactScanner: ContactScanner
    @ObservedObject var cleaner: MediaCleaner
    
    var onNavigateToCategory: (MediaCategory) -> Void
    
    @State private var storageStats = StorageStats()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Storage Dashboard Gauge
                    StorageGaugeView(
                        usedPercentage: storageStats.usedPercentage,
                        usedText: StorageManager.formatBytes(storageStats.usedBytes),
                        freeText: StorageManager.formatBytes(storageStats.freeBytes),
                        totalText: StorageManager.formatBytes(storageStats.totalBytes)
                    )
                    .padding(.horizontal)
                    
                    // Cleanable Space Summary Pill Banner
                    let totalCleanable = scanner.totalSimilarBytes + scanner.totalScreenshotBytes + scanner.totalVideoBytes + scanner.totalBlurryBytes
                    if totalCleanable > 0 {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.blue.opacity(0.2)).frame(width: 40, height: 40)
                                Image(systemName: "sparkles")
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cleanable Storage Found")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Text("You can free up around \(StorageManager.formatBytes(totalCleanable))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .liquidGlassCard(cornerRadius: 18)
                        .padding(.horizontal)
                    }
                    
                    // Quick Scan Action Button
                    if scanner.isScanning {
                        VStack(spacing: 10) {
                            ProgressView(value: scanner.scanProgress)
                                .tint(.blue)
                            Text(scanner.statusMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .liquidGlassCard(cornerRadius: 18)
                        .padding(.horizontal)
                    } else {
                        PrimaryActionButton(
                            title: "Quick Storage Scan",
                            iconName: "magnifyingglass.circle.fill",
                            color: .blue
                        ) {
                            Task {
                                refreshStats()
                                await scanner.scanAll()
                                if permissionManager.hasContactsAccess {
                                    await contactScanner.scanContacts()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Core Cleanup Section (Includes All Photos & Direct Navigation)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Core Cleanup")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        Button {
                            onNavigateToCategory(.similarPhotos)
                        } label: {
                            CategoryCardView(
                                category: .similarPhotos,
                                count: scanner.photoGroups.reduce(0) { $0 + $1.items.count },
                                formattedBytes: StorageManager.formatBytes(scanner.totalSimilarBytes),
                                subtitle: "Group duplicate & shot bursts"
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        
                        Button {
                            onNavigateToCategory(.screenshots)
                        } label: {
                            CategoryCardView(
                                category: .screenshots,
                                count: scanner.screenshots.count,
                                formattedBytes: StorageManager.formatBytes(scanner.totalScreenshotBytes),
                                subtitle: "Bulk clean device screenshots"
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        
                        Button {
                            onNavigateToCategory(.largeVideos)
                        } label: {
                            CategoryCardView(
                                category: .largeVideos,
                                count: scanner.largeVideos.count,
                                formattedBytes: StorageManager.formatBytes(scanner.totalVideoBytes),
                                subtitle: "Find largest videos on device"
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        
                        Button {
                            onNavigateToCategory(.duplicateContacts)
                        } label: {
                            CategoryCardView(
                                category: .duplicateContacts,
                                count: contactScanner.contactGroups.count,
                                formattedBytes: "",
                                subtitle: "Merge matching name & numbers"
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        
                        Button {
                            onNavigateToCategory(.allPhotos)
                        } label: {
                            CategoryCardView(
                                category: .allPhotos,
                                count: scanner.allPhotos.count,
                                formattedBytes: StorageManager.formatBytes(scanner.totalAllPhotosBytes),
                                subtitle: "Browse full photo library grid"
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 80)
                }
                .padding(.vertical)
            }
            .navigationTitle("Cleanup")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            _ = await permissionManager.requestPhotoAccess()
                            _ = await permissionManager.requestContactAccess()
                            refreshStats()
                            await scanner.scanAll()
                            await contactScanner.scanContacts()
                        }
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.headline)
                    }
                }
            }
            .onAppear {
                refreshStats()
                if permissionManager.hasPhotoAccess {
                    Task {
                        await scanner.scanAll()
                    }
                }
            }
        }
    }
    
    private func refreshStats() {
        storageStats = StorageManager.shared.getStorageStats()
    }
}
