import Foundation
import LocalAuthentication
import UIKit
import Photos
import Combine

@MainActor
class VaultManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var vaultItems: [VaultItem] = []
    @Published var authErrorMessage: String? = nil
    
    private let vaultFolder: URL
    
    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.vaultFolder = docs.appendingPathComponent("SecureVault", isDirectory: true)
        createVaultDirectoryIfNeeded()
        loadVaultItems()
    }
    
    private func createVaultDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: vaultFolder.path) {
            try? FileManager.default.createDirectory(at: vaultFolder, withIntermediateDirectories: true)
        }
    }
    
    func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) ||
           context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            
            let reason = "Authenticate to unlock your Private Vault."
            do {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
                self.isAuthenticated = success
                if success {
                    self.authErrorMessage = nil
                    self.loadVaultItems()
                }
                return success
            } catch {
                self.authErrorMessage = error.localizedDescription
                self.isAuthenticated = false
                return false
            }
        } else {
            // Biometrics / passcode unavailable, fallback to unlocked
            self.isAuthenticated = true
            self.authErrorMessage = nil
            self.loadVaultItems()
            return true
        }
    }
    
    func lockVault() {
        isAuthenticated = false
    }
    
    func loadVaultItems() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: vaultFolder, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) else {
            return
        }
        
        var items: [VaultItem] = []
        for file in files {
            let attrs = try? FileManager.default.attributesOfItem(atPath: file.path)
            let size = (attrs?[.size] as? Int64) ?? 0
            let date = (attrs?[.creationDate] as? Date) ?? Date()
            
            let item = VaultItem(
                id: UUID(),
                title: file.lastPathComponent,
                dateAdded: date,
                fileSize: size,
                relativePath: file.path
            )
            items.append(item)
        }
        
        self.vaultItems = items
    }
    
    func importImageToVault(image: UIImage, title: String) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return false }
        let filename = "\(UUID().uuidString)_\(title).jpg"
        let targetURL = vaultFolder.appendingPathComponent(filename)
        
        do {
            try data.write(to: targetURL, options: .atomic)
            loadVaultItems()
            return true
        } catch {
            print("Failed to save image to vault: \(error)")
            return false
        }
    }
    
    func unhideVaultItemToPhotos(_ item: VaultItem) async -> Bool {
        guard let image = UIImage(contentsOfFile: item.relativePath) else { return false }
        
        let success: Bool = await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { saved, _ in
                continuation.resume(returning: saved)
            }
        }
        
        if success {
            deleteVaultItem(item)
            return true
        }
        return false
    }
    
    func deleteVaultItem(_ item: VaultItem) {
        let fileURL = URL(fileURLWithPath: item.relativePath)
        try? FileManager.default.removeItem(at: fileURL)
        loadVaultItems()
    }
}
