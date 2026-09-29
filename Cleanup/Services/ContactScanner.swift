import Foundation
import Contacts
import Combine

@MainActor
class ContactScanner: ObservableObject {
    @Published var isScanning: Bool = false
    @Published var contactGroups: [ContactGroup] = []
    @Published var allContactsList: [ContactItem] = []
    @Published var unnamedContactsList: [ContactItem] = []
    @Published var totalDuplicatesCount: Int = 0
    @Published var statusMessage: String = ""
    
    private let store = CNContactStore()
    
    func scanContacts() async {
        isScanning = true
        statusMessage = "Scanning contacts..."
        
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .authorized else {
            isScanning = false
            return
        }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactImageDataAvailableKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor
        ]
        
        var allContacts: [CNContact] = []
        let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
        
        do {
            try store.enumerateContacts(with: fetchRequest) { contact, _ in
                allContacts.append(contact)
            }
        } catch {
            print("Error fetching contacts: \(error)")
            isScanning = false
            return
        }
        
        // Build All Contacts List
        let allItems = allContacts.map { ContactItem(id: $0.identifier, contact: $0, isSelected: false) }
        self.allContactsList = allItems.sorted(by: { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending })
        
        // Build Unnamed Contacts List (empty givenName and familyName)
        let unnamedItems = allContacts.filter { c in
            c.givenName.trimmingCharacters(in: .whitespaces).isEmpty &&
            c.familyName.trimmingCharacters(in: .whitespaces).isEmpty
        }.map { ContactItem(id: $0.identifier, contact: $0, isSelected: true) }
        self.unnamedContactsList = unnamedItems
        
        // Group by Name, Phone, and Email
        var duplicateGroups: [ContactGroup] = []
        
        // 1. Group by exact Name
        var nameMap: [String: [CNContact]] = [:]
        for c in allContacts {
            let fullName = "\(c.givenName) \(c.familyName)".trimmingCharacters(in: .whitespaces).lowercased()
            if !fullName.isEmpty {
                nameMap[fullName, default: []].append(c)
            }
        }
        
        for (name, list) in nameMap where list.count >= 2 {
            let items = list.map { ContactItem(id: $0.identifier, contact: $0, isSelected: true) }
            let group = ContactGroup(matchReason: "Duplicate Name: \(name.capitalized)", contacts: items)
            duplicateGroups.append(group)
        }
        
        // 2. Group by Phone Number
        var phoneMap: [String: [CNContact]] = [:]
        for c in allContacts {
            for phone in c.phoneNumbers {
                let digits = phone.value.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if digits.count >= 7 {
                    let suffix = String(digits.suffix(10))
                    phoneMap[suffix, default: []].append(c)
                }
            }
        }
        
        for (phone, list) in phoneMap where list.count >= 2 {
            let identifiers = Set(list.map { $0.identifier })
            let alreadyExists = duplicateGroups.contains { g in
                Set(g.contacts.map { $0.id }).isSuperset(of: identifiers)
            }
            if !alreadyExists {
                let items = list.map { ContactItem(id: $0.identifier, contact: $0, isSelected: true) }
                let group = ContactGroup(matchReason: "Matching Phone: \(phone)", contacts: items)
                duplicateGroups.append(group)
            }
        }
        
        self.contactGroups = duplicateGroups
        self.totalDuplicatesCount = duplicateGroups.reduce(0) { $0 + $1.contacts.count }
        self.isScanning = false
        self.statusMessage = "Scan complete."
    }
    
    func mergeGroup(_ group: ContactGroup) async -> Bool {
        guard group.contacts.count >= 2 else { return false }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor
        ]
        
        var fullContacts: [CNMutableContact] = []
        for cItem in group.contacts {
            if let full = try? store.unifiedContact(withIdentifier: cItem.id, keysToFetch: keysToFetch).mutableCopy() as? CNMutableContact {
                fullContacts.append(full)
            }
        }
        
        guard let masterContact = fullContacts.first else { return false }
        
        let saveRequest = CNSaveRequest()
        var existingNumbers = Set(masterContact.phoneNumbers.map { $0.value.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined() })
        var existingEmails = Set(masterContact.emailAddresses.map { $0.value as String })
        
        var updatedPhones = masterContact.phoneNumbers
        var updatedEmails = masterContact.emailAddresses
        
        for duplicate in fullContacts.dropFirst() {
            for phone in duplicate.phoneNumbers {
                let digits = phone.value.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if !digits.isEmpty && !existingNumbers.contains(digits) {
                    existingNumbers.insert(digits)
                    updatedPhones.append(phone)
                }
            }
            for email in duplicate.emailAddresses {
                let emailStr = email.value as String
                if !emailStr.isEmpty && !existingEmails.contains(emailStr) {
                    existingEmails.insert(emailStr)
                    updatedEmails.append(email)
                }
            }
            
            saveRequest.delete(duplicate)
        }
        
        masterContact.phoneNumbers = updatedPhones
        masterContact.emailAddresses = updatedEmails
        saveRequest.update(masterContact)
        
        do {
            try store.execute(saveRequest)
            await scanContacts()
            return true
        } catch {
            print("Error merging contacts: \(error)")
            return false
        }
    }
}
