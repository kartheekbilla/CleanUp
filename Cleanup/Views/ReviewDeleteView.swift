import SwiftUI

struct ReviewDeleteView: View {
    let similarPhotos: [PhotoAssetItem]
    let screenshots: [PhotoAssetItem]
    let largeVideos: [PhotoAssetItem]
    let blurryPhotos: [PhotoAssetItem]
    let contacts: [ContactItem]
    
    let onConfirmDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var totalSelectedBytes: Int64 {
        let p = similarPhotos.reduce(0) { $0 + $1.fileSize }
        let s = screenshots.reduce(0) { $0 + $1.fileSize }
        let v = largeVideos.reduce(0) { $0 + $1.fileSize }
        let b = blurryPhotos.reduce(0) { $0 + $1.fileSize }
        return p + s + v + b
    }
    
    var totalSelectedCount: Int {
        similarPhotos.count + screenshots.count + largeVideos.count + blurryPhotos.count + contacts.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header Space Card
                VStack(spacing: 8) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("Ready to Clean")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(StorageManager.formatBytes(totalSelectedBytes))
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Space to be freed across \(totalSelectedCount) items")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                )
                .padding(.horizontal)
                
                // Safety Information Callout
                HStack(spacing: 12) {
                    Image(systemName: "shield.checkmark.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Safe Clean Protection")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Photos & videos are moved to Recently Deleted. You can restore them anytime within 30 days.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(14)
                .padding(.horizontal)
                
                // Detailed Item Breakdown List
                List {
                    Section(header: Text("Items Breakdown")) {
                        if !similarPhotos.isEmpty {
                            ReviewRowView(
                                title: "Similar Photos",
                                count: similarPhotos.count,
                                formattedBytes: StorageManager.formatBytes(similarPhotos.reduce(0) { $0 + $1.fileSize }),
                                iconName: MediaCategory.similarPhotos.iconName,
                                color: MediaCategory.similarPhotos.themeColor
                            )
                        }
                        
                        if !screenshots.isEmpty {
                            ReviewRowView(
                                title: "Screenshots",
                                count: screenshots.count,
                                formattedBytes: StorageManager.formatBytes(screenshots.reduce(0) { $0 + $1.fileSize }),
                                iconName: MediaCategory.screenshots.iconName,
                                color: MediaCategory.screenshots.themeColor
                            )
                        }
                        
                        if !largeVideos.isEmpty {
                            ReviewRowView(
                                title: "Large Videos",
                                count: largeVideos.count,
                                formattedBytes: StorageManager.formatBytes(largeVideos.reduce(0) { $0 + $1.fileSize }),
                                iconName: MediaCategory.largeVideos.iconName,
                                color: MediaCategory.largeVideos.themeColor
                            )
                        }
                        
                        if !blurryPhotos.isEmpty {
                            ReviewRowView(
                                title: "Blurry Photos",
                                count: blurryPhotos.count,
                                formattedBytes: StorageManager.formatBytes(blurryPhotos.reduce(0) { $0 + $1.fileSize }),
                                iconName: MediaCategory.blurryPhotos.iconName,
                                color: MediaCategory.blurryPhotos.themeColor
                            )
                        }
                        
                        if !contacts.isEmpty {
                            ReviewRowView(
                                title: "Duplicate Contacts",
                                count: contacts.count,
                                formattedBytes: "Contacts",
                                iconName: MediaCategory.duplicateContacts.iconName,
                                color: MediaCategory.duplicateContacts.themeColor
                            )
                        }
                    }
                }
                .listStyle(.insetGrouped)
                
                // Action Buttons
                VStack(spacing: 12) {
                    PrimaryActionButton(
                        title: "Confirm & Clean \(StorageManager.formatBytes(totalSelectedBytes))",
                        iconName: "checkmark.circle.fill",
                        color: .red
                    ) {
                        dismiss()
                        onConfirmDelete()
                    }
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.callout)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Review Before Delete")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ReviewRowView: View {
    let title: String
    let count: Int
    let formattedBytes: String
    let iconName: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(color)
                .frame(width: 28)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formattedBytes)
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
        }
    }
}
