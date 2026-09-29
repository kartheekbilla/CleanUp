import SwiftUI

enum ThemeOption: String, CaseIterable, Identifiable {
    case system = "System Default"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .system: return "iphone"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct ExtrasSessionView: View {
    @AppStorage("userThemePreference") private var selectedThemeRaw: String = ThemeOption.system.rawValue
    @State private var storageStats = StorageStats()
    
    var selectedTheme: ThemeOption {
        ThemeOption(rawValue: selectedThemeRaw) ?? .system
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Banner
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.18))
                                .frame(width: 48, height: 48)
                            Image(systemName: "slider.horizontal.3")
                                .font(.title2)
                                .foregroundColor(.purple)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("App Preferences & Extras")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("Customize appearance & Home Screen Widgets.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .liquidGlassCard(cornerRadius: 22)
                    .padding(.horizontal)
                    
                    // 1. Appearance / Theme Section
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Appearance Theme")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ForEach(ThemeOption.allCases) { option in
                                Button {
                                    withAnimation {
                                        selectedThemeRaw = option.rawValue
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(selectedTheme == option ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                                .frame(width: 38, height: 38)
                                            Image(systemName: option.iconName)
                                                .foregroundColor(selectedTheme == option ? .blue : .primary)
                                        }
                                        
                                        Text(option.rawValue)
                                            .font(.body)
                                            .fontWeight(selectedTheme == option ? .bold : .regular)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        if selectedTheme == option {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(selectedTheme == option ? Color.blue.opacity(0.08) : Color.clear)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 24)
                        .padding(.horizontal)
                    }
                    
                    // 2. Home Screen Storage Widget Section
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Home Screen Storage Widget")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            // Interactive Widget Mockup Preview
                            VStack(spacing: 10) {
                                HStack {
                                    Image(systemName: "circle.grid.2x2.fill")
                                        .foregroundColor(.blue)
                                    Text("Cleanup Widget Preview")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                            .frame(width: 54, height: 54)
                                        Circle()
                                            .trim(from: 0, to: CGFloat(storageStats.usedPercentage))
                                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                            .rotationEffect(.degrees(-90))
                                            .frame(width: 54, height: 54)
                                        Text("\(Int(storageStats.usedPercentage * 100))%")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Storage Status")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                        Text("\(StorageManager.formatBytes(storageStats.freeBytes)) Free")
                                            .font(.caption)
                                            .foregroundColor(.emeraldGreen)
                                            .fontWeight(.semibold)
                                        Text("\(StorageManager.formatBytes(storageStats.usedBytes)) Used")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                                )
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("How to Add to Home Screen:")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                
                                Label("Touch and hold any empty area on Home Screen.", systemImage: "1.circle.fill")
                                    .font(.caption)
                                Label("Tap the (+) Plus button in top left corner.", systemImage: "2.circle.fill")
                                    .font(.caption)
                                Label("Search for 'Cleanup' and choose widget size.", systemImage: "3.circle.fill")
                                    .font(.caption)
                                Label("Tap Add Widget and position on your screen!", systemImage: "4.circle.fill")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        .padding(18)
                        .liquidGlassCard(cornerRadius: 24)
                        .padding(.horizontal)
                    }
                    
                    // 3. Privacy & App Info Card
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "shield.checkerboard")
                                .font(.title2)
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("100% On-Device Privacy")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Text("No media or contacts leave your iPhone.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Cleanup App Version")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("v2.0 Liquid Glass Edition")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(18)
                    .liquidGlassCard(cornerRadius: 22)
                    .padding(.horizontal)
                    .padding(.bottom, 80)
                }
                .padding(.vertical)
            }
            .navigationTitle("Extras")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                storageStats = StorageManager.shared.getStorageStats()
            }
        }
    }
}
