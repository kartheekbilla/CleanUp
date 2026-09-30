import SwiftUI
import Photos

// MARK: - Scroll Offset Tracking Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Liquid Glass View Modifier
struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    var highlightOpacity: Double = 0.3
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(highlightOpacity), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.6), Color.white.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func liquidGlassCard(cornerRadius: CGFloat = 24, highlightOpacity: Double = 0.3) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius, highlightOpacity: highlightOpacity))
    }
}

// MARK: - Async PHAsset Thumbnail View
struct PHAssetImageView: View {
    let asset: PHAsset
    let targetSize: CGSize
    let contentMode: ContentMode
    
    @State private var image: UIImage? = nil
    
    init(asset: PHAsset, targetSize: CGSize = CGSize(width: 300, height: 300), contentMode: ContentMode = .fill) {
        self.asset = asset
        self.targetSize = targetSize
        self.contentMode = contentMode
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    Color.gray.opacity(0.15)
                    ProgressView()
                }
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { img, _ in
            DispatchQueue.main.async {
                self.image = img
            }
        }
    }
}

// MARK: - Storage Ring Gauge View (Glassy liquid design)
struct StorageGaugeView: View {
    let usedPercentage: Double
    let usedText: String
    let freeText: String
    let totalText: String
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Outer Liquid Glow Halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.15), Color.clear],
                            center: .center,
                            startRadius: 80,
                            endRadius: 130
                        )
                    )
                    .frame(width: 230, height: 230)
                
                // Background Track Ring
                Circle()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 22)
                    .frame(width: 190, height: 190)
                
                // Active Used Storage Gradient Ring
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(usedPercentage, 1.0)))
                    .stroke(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 22, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 190, height: 190)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: usedPercentage)
                
                // Glass Center Content
                VStack(spacing: 4) {
                    Text("\(Int(usedPercentage * 100))%")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Storage Used")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text(usedText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.blue).frame(width: 8, height: 8)
                        Text("Used Storage")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    Text(usedText)
                        .font(.callout)
                        .fontWeight(.bold)
                }
                
                Divider()
                    .frame(height: 28)
                
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.emeraldGreen).frame(width: 8, height: 8)
                        Text("Free Storage")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    Text(freeText)
                        .font(.callout)
                        .fontWeight(.bold)
                }
            }
        }
        .padding(24)
        .liquidGlassCard(cornerRadius: 30, highlightOpacity: 0.4)
    }
}

extension Color {
    static let emeraldGreen = Color(red: 0.2, green: 0.78, blue: 0.45)
}

// MARK: - Glassy Category Card View
struct CategoryCardView: View {
    let category: MediaCategory
    let count: Int
    let formattedBytes: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Glowing Icon Capsule
            ZStack {
                Circle()
                    .fill(category.themeColor.opacity(0.18))
                    .frame(width: 52, height: 52)
                
                Image(systemName: category.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(category.themeColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(category.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                if !formattedBytes.isEmpty && formattedBytes != "0 B" {
                    Text(formattedBytes)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(category.themeColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(category.themeColor.opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(category.themeColor.opacity(0.3), lineWidth: 0.5)
                                )
                        )
                }
                
                HStack(spacing: 4) {
                    if count > 0 {
                        Text("\(count) items")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
        }
        .padding(16)
        .liquidGlassCard(cornerRadius: 22, highlightOpacity: 0.25)
    }
}

// MARK: - Glassy Action Button
struct PrimaryActionButton: View {
    let title: String
    let iconName: String
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.headline)
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                }
                .shadow(color: color.opacity(0.35), radius: 10, x: 0, y: 5)
            )
        }
    }
}
