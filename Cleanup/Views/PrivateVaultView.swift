import SwiftUI
import Photos

struct PrivateVaultView: View {
    @StateObject private var vaultManager = VaultManager()
    @State private var selectedVaultImage: UIImage? = nil
    @State private var selectedVaultItem: VaultItem? = nil
    @State private var showUnhideSuccessAlert: Bool = false
    
    var body: some View {
        VStack {
            if !vaultManager.isAuthenticated {
                VStack(spacing: 24) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.12))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Private Storage Vault")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Protected by Face ID / Touch ID / Passcode. Keep your sensitive photos safely hidden.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    if let err = vaultManager.authErrorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button(action: {
                        Task {
                            _ = await vaultManager.authenticate()
                        }
                    }) {
                        HStack {
                            Image(systemName: "faceid")
                            Text("Unlock Vault")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
            } else {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Private Vault Items (\(vaultManager.vaultItems.count))")
                                .font(.headline)
                            Text("Encrypted on device")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Lock Vault") {
                            vaultManager.lockVault()
                        }
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                    
                    if vaultManager.vaultItems.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("Your Vault is Empty")
                                .font(.headline)
                            Text("Locked photos from All Photos will appear safely here.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(vaultManager.vaultItems) { item in
                                HStack(spacing: 12) {
                                    // Thumbnail - Tapping opens Photo Viewer ONLY
                                    Button(action: {
                                        if let img = UIImage(contentsOfFile: item.relativePath) {
                                            selectedVaultImage = img
                                            selectedVaultItem = item
                                        }
                                    }) {
                                        if let uiImg = UIImage(contentsOfFile: item.relativePath) {
                                            Image(uiImage: uiImg)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 50, height: 50)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } else {
                                            Image(systemName: "doc.fill")
                                                .font(.title2)
                                                .foregroundColor(.blue)
                                                .frame(width: 50, height: 50)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .lineLimit(1)
                                        Text("\(StorageManager.formatBytes(item.fileSize)) • \(item.dateAdded.formatted(date: .numeric, time: .shortened))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .onTapGesture {
                                        if let img = UIImage(contentsOfFile: item.relativePath) {
                                            selectedVaultImage = img
                                            selectedVaultItem = item
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Action Buttons: Viewing Eye & Dedicated Unhide Button
                                    HStack(spacing: 12) {
                                        // 1. Separate Eye Viewer Button (View Only)
                                        Button(action: {
                                            if let img = UIImage(contentsOfFile: item.relativePath) {
                                                selectedVaultImage = img
                                                selectedVaultItem = item
                                            }
                                        }) {
                                            Image(systemName: "eye.fill")
                                                .foregroundColor(.secondary)
                                                .padding(6)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        // 2. Dedicated Separate Unhide Button (Unhides to All Photos)
                                        Button(action: {
                                            Task {
                                                let success = await vaultManager.unhideVaultItemToPhotos(item)
                                                if success {
                                                    showUnhideSuccessAlert = true
                                                }
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "lock.open.fill")
                                                Text("Unhide")
                                            }
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(Color.blue.opacity(0.12))
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    let item = vaultManager.vaultItems[index]
                                    vaultManager.deleteVaultItem(item)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
                // Pure Image Preview Modal Sheet (Strictly for Viewing the Photo)
                .sheet(item: $selectedVaultItem) { item in
                    if let image = selectedVaultImage {
                        NavigationStack {
                            VStack {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .padding()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.ignoresSafeArea())
                            .navigationTitle(item.title)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        selectedVaultImage = nil
                                        selectedVaultItem = nil
                                    }
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                }
                            }
                        }
                    }
                }
                .alert("Photo Restored", isPresented: $showUnhideSuccessAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("The photo has been unhidden and restored back to your Photo Library!")
                }
            }
        }
        .navigationTitle("Private Vault")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                _ = await vaultManager.authenticate()
            }
        }
    }
}
