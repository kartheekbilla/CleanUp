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
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    // Side-by-Side Swipable Gallery Page View
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            VStack {
                                Spacer()
                                PHAssetImageView(asset: item.asset, targetSize: CGSize(width: 1200, height: 1200), contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .padding(.horizontal, 12)
                                    .shadow(color: Color.black.opacity(0.6), radius: 15, x: 0, y: 8)
                                Spacer()
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    
                    // Bottom Control Bar (Move to Vault 🔒 & Delete)
                    VStack(spacing: 12) {
                        if let msg = lockStatusMessage {
                            Text(msg)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.yellow)
                                .transition(.opacity)
                        }
                        
                        HStack(spacing: 20) {
                            // Lock to Private Vault Button
                            Button(action: lockCurrentItemToVault) {
                                HStack(spacing: 8) {
                                    if isLocking {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "lock.shield.fill")
                                        Text("Move to Private Vault")
                                    }
                                }
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
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
                                Image(systemName: "trash.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(
                                        Circle()
                                            .fill(Color.red)
                                            .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)
                                    )
                            }
                        }
                        .padding(.bottom, 24)
                    }
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
    }
    
    private func lockCurrentItemToVault() {
        guard let item = currentItem else { return }
        isLocking = true
        lockStatusMessage = "Encrypting & moving to Private Vault..."
        
        Task {
            let manager = PHImageManager.default()
            let options = PHVideoRequestOptions()
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
