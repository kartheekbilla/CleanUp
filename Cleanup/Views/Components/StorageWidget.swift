import WidgetKit
import SwiftUI

struct StorageWidgetEntry: TimelineEntry {
    let date: Date
    let usedPercentage: Double
    let usedBytes: Int64
    let freeBytes: Int64
}

struct StorageWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StorageWidgetEntry {
        StorageWidgetEntry(date: Date(), usedPercentage: 0.65, usedBytes: 65 * 1024 * 1024 * 1024, freeBytes: 35 * 1024 * 1024 * 1024)
    }

    func getSnapshot(in context: Context, completion: @escaping (StorageWidgetEntry) -> Void) {
        let stats = StorageManager.shared.getStorageStats()
        let entry = StorageWidgetEntry(date: Date(), usedPercentage: stats.usedPercentage, usedBytes: stats.usedBytes, freeBytes: stats.freeBytes)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StorageWidgetEntry>) -> Void) {
        let stats = StorageManager.shared.getStorageStats()
        let entry = StorageWidgetEntry(date: Date(), usedPercentage: stats.usedPercentage, usedBytes: stats.usedBytes, freeBytes: stats.freeBytes)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct StorageWidgetEntryView : View {
    var entry: StorageWidgetProvider.Entry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "circle.grid.2x2.fill")
                    .foregroundColor(.blue)
                Text("Cleanup")
                    .font(.caption)
                    .fontWeight(.bold)
                Spacer()
            }
            
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: CGFloat(entry.usedPercentage))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 44, height: 44)
                    Text("\(Int(entry.usedPercentage * 100))%")
                        .font(.system(size: 11, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(StorageManager.formatBytes(entry.freeBytes)) Free")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("\(StorageManager.formatBytes(entry.usedBytes)) Used")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
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
