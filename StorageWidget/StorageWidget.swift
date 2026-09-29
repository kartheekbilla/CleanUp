import WidgetKit
import SwiftUI

struct StorageWidgetEntry: TimelineEntry {
    let date: Date
    let usedPercentage: Double
    let usedBytes: Int64
    let freeBytes: Int64
    let totalBytes: Int64
}

struct StorageWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StorageWidgetEntry {
        StorageWidgetEntry(
            date: Date(),
            usedPercentage: 0.68,
            usedBytes: 88 * 1024 * 1024 * 1024,
            freeBytes: 40 * 1024 * 1024 * 1024,
            totalBytes: 128 * 1024 * 1024 * 1024
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StorageWidgetEntry) -> Void) {
        let stats = fetchStats()
        let entry = StorageWidgetEntry(
            date: Date(),
            usedPercentage: stats.usedPercentage,
            usedBytes: stats.usedBytes,
            freeBytes: stats.freeBytes,
            totalBytes: stats.totalBytes
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StorageWidgetEntry>) -> Void) {
        let stats = fetchStats()
        let entry = StorageWidgetEntry(
            date: Date(),
            usedPercentage: stats.usedPercentage,
            usedBytes: stats.usedBytes,
            freeBytes: stats.freeBytes,
            totalBytes: stats.totalBytes
        )
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func fetchStats() -> (usedPercentage: Double, usedBytes: Int64, freeBytes: Int64, totalBytes: Int64) {
        let fileManager = FileManager.default
        let path = NSHomeDirectory()
        guard let systemAttributes = try? fileManager.attributesOfFileSystem(forPath: path),
              let totalBytes = (systemAttributes[.systemSize] as? NSNumber)?.int64Value,
              let freeBytes = (systemAttributes[.systemFreeSize] as? NSNumber)?.int64Value,
              totalBytes > 0 else {
            return (0.68, 88 * 1024 * 1024 * 1024, 40 * 1024 * 1024 * 1024, 128 * 1024 * 1024 * 1024)
        }
        let usedBytes = totalBytes - freeBytes
        let usedPercentage = Double(usedBytes) / Double(totalBytes)
        return (usedPercentage, usedBytes, freeBytes, totalBytes)
    }
}

struct StorageWidgetEntryView : View {
    @Environment(\.widgetFamily) var family
    var entry: StorageWidgetProvider.Entry
    
    var themeColors: [Color] {
        if entry.usedPercentage > 0.90 {
            return [.orange, .red]
        } else if entry.usedPercentage > 0.75 {
            return [.blue, .purple]
        } else {
            return [.blue, .teal]
        }
    }

    var body: some View {
        switch family {
        case .systemMedium:
            mediumWidgetBody
        default:
            smallWidgetBody
        }
    }
    
    // Small Widget Layout
    var smallWidgetBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(themeColors.first)
                Text("Cleanup")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 7)
                        .frame(width: 52, height: 52)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(min(1.0, max(0.0, entry.usedPercentage))))
                        .stroke(
                            LinearGradient(colors: themeColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 52, height: 52)
                    
                    Text("\(Int(entry.usedPercentage * 100))%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Available")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(formatBytes(entry.freeBytes))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Used")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(formatBytes(entry.usedBytes))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary.opacity(0.8))
                    }
                }
            }
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    // Medium Widget Layout
    var mediumWidgetBody: some View {
        HStack(spacing: 16) {
            // Left Storage Arc Gauge
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 10)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: CGFloat(min(1.0, max(0.0, entry.usedPercentage))))
                    .stroke(
                        LinearGradient(colors: themeColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 80, height: 80)
                
                VStack(spacing: 0) {
                    Text("\(Int(entry.usedPercentage * 100))%")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    Text("USED")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
            
            // Right Detailed Metrics
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "internaldrive.fill")
                            .foregroundColor(.blue)
                        Text("Cleanup Storage")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    Spacer()
                }
                
                // Progress Gauge Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(LinearGradient(colors: themeColors, startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(12, geo.size.width * CGFloat(entry.usedPercentage)), height: 8)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FREE SPACE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(formatBytes(entry.freeBytes))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("TOTAL CAPACITY")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(formatBytes(entry.totalBytes))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(16)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct StorageWidget: Widget {
    let kind: String = "StorageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StorageWidgetProvider()) { entry in
            StorageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Cleanup Storage Gauge")
        .description("Monitor available iPhone storage directly from your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
