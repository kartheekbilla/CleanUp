import Foundation
import Photos
import Contacts
import SwiftUI

// MARK: - Storage Breakdown Statistics
struct StorageStats {
    var totalBytes: Int64 = 0
    var freeBytes: Int64 = 0
    var usedBytes: Int64 = 0
    
    var similarPhotosBytes: Int64 = 0
    var screenshotsBytes: Int64 = 0
    var largeVideosBytes: Int64 = 0
    var blurryPhotosBytes: Int64 = 0
    
    var similarPhotosCount: Int = 0
    var screenshotsCount: Int = 0
    var largeVideosCount: Int = 0
    var duplicateContactsCount: Int = 0
    var blurryPhotosCount: Int = 0
    
    var totalCleanableBytes: Int64 {
        return similarPhotosBytes + screenshotsBytes + largeVideosBytes + blurryPhotosBytes
    }
    
    var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
}

// MARK: - Media Category Type
enum MediaCategory: String, CaseIterable, Identifiable {
    case similarPhotos = "Similar Photos"
    case screenshots = "Screenshots"
    case largeVideos = "Large Videos"
    case duplicateContacts = "Duplicate Contacts"
    case blurryPhotos = "Blurry Photos"
    case allPhotos = "All Photos"
    case videoCompressor = "Video Compressor"
    case swipeCleaner = "Swipe Cleaner"
    case privateVault = "Private Vault"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .similarPhotos: return "photo.on.rectangle.angled"
        case .screenshots: return "iphone.gen3"
        case .largeVideos: return "film.stack"
        case .duplicateContacts: return "person.2"
        case .blurryPhotos: return "eye.slash"
        case .allPhotos: return "photo.stack"
        case .videoCompressor: return "arrow.down.right.and.arrow.up.left.square"
        case .swipeCleaner: return "hand.draw"
        case .privateVault: return "lock.shield"
        }
    }
    
    var themeColor: Color {
        switch self {
        case .similarPhotos: return .blue
        case .screenshots: return .purple
        case .largeVideos: return .orange
        case .duplicateContacts: return .green
        case .blurryPhotos: return .pink
        case .allPhotos: return .cyan
        case .videoCompressor: return .indigo
        case .swipeCleaner: return .teal
        case .privateVault: return .secondary
        }
    }
}

// MARK: - Photo Asset Item Wrapper
struct PhotoAssetItem: Identifiable, Hashable {
    let id: String
    let asset: PHAsset
    let fileSize: Int64
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    var isSelected: Bool = false
    var isBest: Bool = false
    var sharpnessScore: Double = 1.0
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PhotoAssetItem, rhs: PhotoAssetItem) -> Bool {
        lhs.id == rhs.id
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

// MARK: - Photo Group (Cluster of Duplicate / Similar Photos)
struct PhotoGroup: Identifiable {
    let id: UUID = UUID()
    let title: String
    var items: [PhotoAssetItem]
    
    var bestItem: PhotoAssetItem? {
        items.first(where: { $0.isBest }) ?? items.max(by: { ($0.pixelWidth * $0.pixelHeight) < ($1.pixelWidth * $1.pixelHeight) })
    }
    
    var selectedCount: Int {
        items.filter { $0.isSelected }.count
    }
    
    var selectedBytes: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.fileSize }
    }
}

// MARK: - Contact Item Wrapper
struct ContactItem: Identifiable, Hashable {
    let id: String
    let contact: CNContact
    var isSelected: Bool = false
    
    var fullName: String {
        let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Unnamed Contact" : name
    }
    
    var primaryPhone: String {
        contact.phoneNumbers.first?.value.stringValue ?? "No phone"
    }
    
    var primaryEmail: String {
        contact.emailAddresses.first?.value as String? ?? "No email"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ContactItem, rhs: ContactItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Contact Duplicate Group
struct ContactGroup: Identifiable {
    let id: UUID = UUID()
    let matchReason: String
    var contacts: [ContactItem]
    
    var selectedCount: Int {
        contacts.filter { $0.isSelected }.count
    }
}

// MARK: - Vault Item
struct VaultItem: Identifiable, Codable {
    let id: UUID
    let title: String
    let dateAdded: Date
    let fileSize: Int64
    let relativePath: String
}
