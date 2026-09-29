import SwiftUI

enum ContactsSubFilter: String, CaseIterable, Identifiable {
    case duplicates = "Duplicates"
    case allContacts = "All Contacts"
    case unnamed = "Unnamed Numbers"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .duplicates: return "person.2.slash"
        case .allContacts: return "person.3.sequence.fill"
        case .unnamed: return "questionmark.person.dashed"
        }
    }
}

struct ContactsSessionView: View {
    @ObservedObject var scanner: ContactScanner
    @ObservedObject var cleaner: MediaCleaner
    @ObservedObject var permissionManager: PermissionManager
    
    @State private var selectedFilter: ContactsSubFilter = .duplicates
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Glassy Segmented Filter Picker
                HStack(spacing: 6) {
                    ForEach(ContactsSubFilter.allCases) { filter in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedFilter = filter
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: filter.iconName)
                                    .font(.caption)
                                Text(filter.rawValue)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(selectedFilter == filter ? .white : .primary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                Group {
                                    if selectedFilter == filter {
                                        Capsule()
                                            .fill(Color.blue)
                                            .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)
                                    } else {
                                        Capsule()
                                            .fill(Color.primary.opacity(0.05))
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(6)
                .liquidGlassCard(cornerRadius: 30)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                // Active Sub-Session Content
                Group {
                    switch selectedFilter {
                    case .duplicates:
                        DuplicateContactsView(contactScanner: scanner, cleaner: cleaner, permissionManager: permissionManager)
                    case .allContacts:
                        AllContactsListView(scanner: scanner, cleaner: cleaner, permissionManager: permissionManager)
                    case .unnamed:
                        UnnamedContactsListView(scanner: scanner, cleaner: cleaner, permissionManager: permissionManager)
                    }
                }
            }
            .navigationTitle("Contacts Cleaner")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ContactRowView: View {
    let contact: ContactItem
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName)
                    .font(.headline)
                Text(contact.primaryPhone)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if contact.primaryEmail != "No email" {
                    Text(contact.primaryEmail)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .blue : .gray)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - All Contacts List View
struct AllContactsListView: View {
    @ObservedObject var scanner: ContactScanner
    @ObservedObject var cleaner: MediaCleaner
    @ObservedObject var permissionManager: PermissionManager
    
    @State private var selectedIDs: Set<String> = []
    @State private var searchText: String = ""
    @State private var showReviewModal: Bool = false
    @State private var showCompletionScreen: Bool = false
    
    var filteredContacts: [ContactItem] {
        if searchText.isEmpty {
            return scanner.allContactsList
        } else {
            return scanner.allContactsList.filter {
                $0.fullName.localizedCaseInsensitiveContains(searchText) ||
                $0.primaryPhone.contains(searchText) ||
                $0.primaryEmail.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var selectedContacts: [ContactItem] {
        scanner.allContactsList.filter { selectedIDs.contains($0.id) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if scanner.isScanning {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                    Text("Loading address book...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search contacts...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .liquidGlassCard(cornerRadius: 16)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                List {
                    ForEach(filteredContacts) { contact in
                        ContactRowView(
                            contact: contact,
                            isSelected: selectedIDs.contains(contact.id),
                            onToggle: {
                                if selectedIDs.contains(contact.id) {
                                    selectedIDs.remove(contact.id)
                                } else {
                                    selectedIDs.insert(contact.id)
                                }
                            }
                        )
                    }
                }
                .listStyle(.insetGrouped)
                .padding(.bottom, 75)
                
                if !selectedIDs.isEmpty {
                    VStack(spacing: 0) {
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(selectedIDs.count) Selected")
                                    .font(.headline)
                                Text("Ready to remove")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: { showReviewModal = true }) {
                                HStack {
                                    Image(systemName: "person.badge.minus")
                                    Text("Remove Selected")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.red)
                                .cornerRadius(14)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .padding(.bottom, 75)
                    }
                }
            }
        }
        .onAppear {
            if permissionManager.hasContactsAccess && scanner.allContactsList.isEmpty {
                Task {
                    await scanner.scanContacts()
                }
            }
        }
        .sheet(isPresented: $showReviewModal) {
            ReviewDeleteView(
                similarPhotos: [],
                screenshots: [],
                largeVideos: [],
                blurryPhotos: [],
                contacts: selectedContacts,
                onConfirmDelete: {
                    Task {
                        let success = await cleaner.deleteContacts(selectedContacts)
                        if success {
                            await scanner.scanContacts()
                            selectedIDs.removeAll()
                            showCompletionScreen = true
                        }
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showCompletionScreen) {
            CompletionView(
                freedBytes: 0,
                deletedCount: cleaner.lastDeletedCount,
                onDone: { showCompletionScreen = false }
            )
        }
    }
}

// MARK: - Unnamed Contacts List View
struct UnnamedContactsListView: View {
    @ObservedObject var scanner: ContactScanner
    @ObservedObject var cleaner: MediaCleaner
    @ObservedObject var permissionManager: PermissionManager
    
    @State private var selectedIDs: Set<String> = []
    @State private var showReviewModal: Bool = false
    @State private var showCompletionScreen: Bool = false
    
    var selectedContacts: [ContactItem] {
        scanner.unnamedContactsList.filter { selectedIDs.contains($0.id) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if scanner.isScanning {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                    Text("Scanning unnamed numbers...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if scanner.unnamedContactsList.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No Unnamed Contacts Found")
                        .font(.headline)
                    Text("All saved contacts have names assigned.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    Section(header: Text("Contacts Saved Without Name (\(scanner.unnamedContactsList.count))")) {
                        ForEach(scanner.unnamedContactsList) { contact in
                            ContactRowView(
                                contact: contact,
                                isSelected: selectedIDs.contains(contact.id),
                                onToggle: {
                                    if selectedIDs.contains(contact.id) {
                                        selectedIDs.remove(contact.id)
                                    } else {
                                        selectedIDs.insert(contact.id)
                                    }
                                }
                            )
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .padding(.bottom, 75)
                
                if !selectedIDs.isEmpty {
                    VStack(spacing: 0) {
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(selectedIDs.count) Selected")
                                    .font(.headline)
                                Text("Ready to cleanup")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: { showReviewModal = true }) {
                                HStack {
                                    Image(systemName: "person.badge.minus")
                                    Text("Delete Selected")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.red)
                                .cornerRadius(14)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .padding(.bottom, 75)
                    }
                }
            }
        }
        .onAppear {
            if permissionManager.hasContactsAccess && scanner.unnamedContactsList.isEmpty {
                Task {
                    await scanner.scanContacts()
                    selectedIDs = Set(scanner.unnamedContactsList.map { $0.id })
                }
            }
        }
        .sheet(isPresented: $showReviewModal) {
            ReviewDeleteView(
                similarPhotos: [],
                screenshots: [],
                largeVideos: [],
                blurryPhotos: [],
                contacts: selectedContacts,
                onConfirmDelete: {
                    Task {
                        let success = await cleaner.deleteContacts(selectedContacts)
                        if success {
                            await scanner.scanContacts()
                            selectedIDs.removeAll()
                            showCompletionScreen = true
                        }
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showCompletionScreen) {
            CompletionView(
                freedBytes: 0,
                deletedCount: cleaner.lastDeletedCount,
                onDone: { showCompletionScreen = false }
            )
        }
    }
}
