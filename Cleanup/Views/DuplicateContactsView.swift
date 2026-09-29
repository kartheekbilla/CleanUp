import SwiftUI
import Contacts

struct DuplicateContactsView: View {
    @ObservedObject var contactScanner: ContactScanner
    @ObservedObject var cleaner: MediaCleaner
    @ObservedObject var permissionManager: PermissionManager
    
    @State private var showCompletionScreen: Bool = false
    @State private var lastMergedCount: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            if !permissionManager.hasContactsAccess {
                PermissionDeniedView(
                    title: "Contacts Access Required",
                    description: "Cleanup needs access to your contacts to search for duplicate names, phone numbers, and emails.",
                    iconName: "person.crop.circle.badge.exclamationmark",
                    onOpenSettings: {
                        Task {
                            _ = await permissionManager.requestContactAccess()
                        }
                    }
                )
            } else if contactScanner.contactGroups.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No Duplicate Contacts")
                        .font(.headline)
                    Text("Your contacts list is completely clean!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(contactScanner.contactGroups) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                // Compact Header with Simple Merge Symbol Button
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(group.matchReason)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("\(group.contacts.count) duplicates")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Sleek Compact Merge Symbol Button
                                    Button(action: {
                                        mergeGroup(group)
                                    }) {
                                        Image(systemName: "arrow.triangle.merge")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(Color.green)
                                                    .shadow(color: Color.green.opacity(0.3), radius: 4, x: 0, y: 2)
                                            )
                                    }
                                }
                                
                                Divider()
                                
                                // Duplicate Contact Entries in Group
                                VStack(spacing: 6) {
                                    ForEach(Array(group.contacts.enumerated()), id: \.element.id) { index, contact in
                                        HStack(spacing: 10) {
                                            Circle()
                                                .fill(index == 0 ? Color.green.opacity(0.15) : Color.gray.opacity(0.1))
                                                .frame(width: 32, height: 32)
                                                .overlay(
                                                    Text(index == 0 ? "KEEP" : "DUP")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(index == 0 ? .green : .secondary)
                                                )
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(contact.fullName)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                Text(contact.primaryPhone)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                        }
                                        .padding(8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color(UIColor.tertiarySystemGroupedBackground))
                                        )
                                    }
                                }
                            }
                            .padding(14)
                            .liquidGlassCard(cornerRadius: 18)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    .padding(.bottom, 110)
                }
            }
        }
        .navigationTitle("Duplicate Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCompletionScreen) {
            CompletionView(
                freedBytes: 0,
                deletedCount: lastMergedCount,
                onDone: { showCompletionScreen = false }
            )
        }
    }
    
    private func mergeGroup(_ group: ContactGroup) {
        guard group.contacts.count > 1 else { return }
        let count = group.contacts.count - 1
        Task {
            let success = await contactScanner.mergeGroup(group)
            if success {
                lastMergedCount = count
                showCompletionScreen = true
            }
        }
    }
}
