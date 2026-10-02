import SwiftUI
import Photos

struct ImagePreviewGalleryModal: View {
    let items: [PhotoAssetItem]
    @State var selectedIndex: Int
    let cleaner: MediaCleaner
    let vaultManager: VaultManager
    let onPhotosChanged: () async -> Void
    let onDismiss: () -> Void
    
    @State private var isLocking: Bool = false
    @State private var lockStatusMessage: String? = nil
    
    var currentItem: PhotoAssetItem? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !items.isEmpty, let currentItem = currentItem {
                VStack(spacing: 0) {
                    // Top Header Bar
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(selectedIndex + 1) of \(items.count)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.7))
                            Text("\(currentItem.formattedSize) • \(currentItem.pixelWidth) × \(currentItem.pixelHeight)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 50)
                    .padding(.bottom, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.8), Color.black.opacity(0.4), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Side-by-Side Swipable Gallery Page View
                    GeometryReader { geo in
                        TabView(selection: $selectedIndex) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                ZStack {
                                    PHAssetImageView(
                                        asset: item.asset,
                                        targetSize: CGSize(width: geo.size.width * 2, height: geo.size.height * 2),
                                        contentMode: .fit
                                    )
                                    .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .shadow(color: Color.black.opacity(0.5), radius: 12, x: 0, y: 6)
                                }
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .always))
                    }
                    
                    // Bottom Control Bar (Move to Vault 🔒 & Delete)
                    VStack(spacing: 10) {
                        if let msg = lockStatusMessage {
                            Text(msg)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.yellow)
                                .transition(.opacity)
                        }
                        
                        HStack(spacing: 16) {
                            // Lock to Private Vault Button
                            Button(action: lockCurrentItemToVault) {
                                HStack(spacing: 8) {
                                    if isLocking {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "lock.shield.fill")
                                        Text("Move to Vault")
                                    }
                                }
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(Color.indigo)
                                        .shadow(color: Color.indigo.opacity(0.4), radius: 8, x: 0, y: 4)
                                )
                            }
                            .disabled(isLocking)
                            
                            // Delete Photo Button
                            Button(action: deleteCurrentItem) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash.fill")
                                    Text("Delete")
                                }
                                .font(.subheadline)
                                .fontWeight(.bold)
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
                        .padding(.bottom, 36)
                    }
                    .padding(.top, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.5), Color.black.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            } else {
                VStack {
                    Spacer()
                    Text("No photos to preview")
                        .foregroundColor(.white)
                    Button("Close", action: onDismiss)
                        .padding()
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private func lockCurrentItemToVault() {
        guard let item = currentItem else { return }
        isLocking = true
        lockStatusMessage = "Encrypting & moving to Private Vault..."
        
        Task {
            let manager = PHImageManager.default()
            let imageOptions = PHImageRequestOptions()
            imageOptions.isNetworkAccessAllowed = true
            imageOptions.deliveryMode = .highQualityFormat
            
            let uiImage: UIImage? = await withCheckedContinuation { continuation in
                manager.requestImage(for: item.asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: imageOptions) { img, _ in
                    continuation.resume(returning: img)
                }
            }
            
            if let image = uiImage {
                let locked = vaultManager.importImageToVault(image: image, title: "VaultPhoto_\(item.id.prefix(6))")
                if locked {
                    _ = await cleaner.deleteAssets([item])
                    lockStatusMessage = "Moved to Vault! Photo removed from Library."
                    await onPhotosChanged()
                    
                    if items.count <= 1 {
                        onDismiss()
                    } else if selectedIndex >= items.count - 1 {
                        selectedIndex = max(0, items.count - 2)
                    }
                } else {
                    lockStatusMessage = "Failed to lock photo."
                }
            }
            isLocking = false
        }
    }
    
    private func deleteCurrentItem() {
        guard let item = currentItem else { return }
        Task {
            let success = await cleaner.deleteAssets([item])
            if success {
                await onPhotosChanged()
                if items.count <= 1 {
                    onDismiss()
                } else if selectedIndex >= items.count - 1 {
                    selectedIndex = max(0, items.count - 2)
                }
            }
        }
    }
}
