import Foundation
import Photos
import Contacts
import Combine

@MainActor
class MediaCleaner: ObservableObject {
    @Published var isDeleting: Bool = false
    @Published var deleteProgress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var lastFreedBytes: Int64 = 0
    @Published var lastDeletedCount: Int = 0
    
    func deleteAssets(_ items: [PhotoAssetItem]) async -> Bool {
        guard !items.isEmpty else { return true }
        
        isDeleting = true
        statusMessage = "Preparing items for deletion..."
        
        let assetsToDelete = items.map { $0.asset }
        let totalBytes = items.reduce(0) { $0 + $1.fileSize }
        let count = items.count
        
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
            }) { success, error in
                Task { @MainActor in
                    self.isDeleting = false
                    if success {
                        self.lastFreedBytes = totalBytes
                        self.lastDeletedCount = count
                        self.statusMessage = "Successfully removed \(count) items (\(StorageManager.formatBytes(totalBytes)))"
                        continuation.resume(returning: true)
                    } else {
                        self.statusMessage = "Deletion cancelled or failed: \(error?.localizedDescription ?? "Unknown error")"
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    
    func deleteContacts(_ contacts: [ContactItem]) async -> Bool {
        guard !contacts.isEmpty else { return true }
        
        isDeleting = true
        statusMessage = "Removing selected contacts..."
        
        let store = CNContactStore()
        let saveRequest = CNSaveRequest()
        
        for item in contacts {
            if let mutable = item.contact.mutableCopy() as? CNMutableContact {
                saveRequest.delete(mutable)
            }
        }
        
        do {
            try store.execute(saveRequest)
            self.isDeleting = false
            self.lastDeletedCount = contacts.count
            self.statusMessage = "Successfully deleted \(contacts.count) contact(s)."
            return true
        } catch {
            self.isDeleting = false
            self.statusMessage = "Failed to delete contacts: \(error.localizedDescription)"
            return false
        }
    }
}
