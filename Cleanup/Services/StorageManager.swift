import Foundation

class StorageManager {
    static let shared = StorageManager()
    
    private init() {}
    
    func getStorageStats() -> StorageStats {
        var stats = StorageStats()
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        
        if let values = try? homeURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]) {
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = Int64(values.volumeAvailableCapacity ?? 0)
            let used = max(0, total - free)
            
            stats.totalBytes = total
            stats.freeBytes = free
            stats.usedBytes = used
        }
        
        return stats
    }
    
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        return formatter.string(fromByteCount: bytes)
    }
}
