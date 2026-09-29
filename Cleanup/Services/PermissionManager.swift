import Foundation
import Photos
import Contacts
import UIKit
import Combine

@MainActor
class PermissionManager: ObservableObject {
    @Published var photoStatus: PHAuthorizationStatus = .notDetermined
    @Published var contactsStatus: CNAuthorizationStatus = .notDetermined
    
    init() {
        checkPermissions()
    }
    
    func checkPermissions() {
        photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        contactsStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
    
    func requestPhotoAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.photoStatus = status
        return status == .authorized || status == .limited
    }
    
    func requestContactAccess() async -> Bool {
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            self.contactsStatus = granted ? .authorized : .denied
            return granted
        } catch {
            self.contactsStatus = .denied
            return false
        }
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    var hasFullPhotoAccess: Bool {
        photoStatus == .authorized
    }
    
    var hasPhotoAccess: Bool {
        photoStatus == .authorized || photoStatus == .limited
    }
    
    var hasContactsAccess: Bool {
        contactsStatus == .authorized
    }
}
