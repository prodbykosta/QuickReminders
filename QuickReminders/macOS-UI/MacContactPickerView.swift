//
//  MacContactPickerView.swift
//  QuickReminders
//
//  Contact picker UI for macOS
//

#if os(macOS)
import SwiftUI
import Contacts

struct MacContactPickerView: View {
    @Binding var selectedContact: CNContact?
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var contacts: [CNContact] = []
    @State private var isLoading = false
    @State private var permissionDenied = false
    @State private var hasTriedAccess = false

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search contacts", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) {
                        if !searchText.isEmpty && !hasTriedAccess {
                            hasTriedAccess = true
                            loadContacts()
                        }
                    }
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Permission denied message
            if permissionDenied {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Contacts Access Required")
                        .font(.headline)
                    Text("Please grant Contacts access in System Settings to use this feature.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
            }
            // Contacts list
            else if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading contacts...")
                    Spacer()
                }
            } else {
                List(filteredContacts, id: \.identifier) { contact in
                    Button(action: {
                        selectedContact = contact
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(contact.givenName) \(contact.familyName)")
                                    .font(.body)
                                if !contact.phoneNumbers.isEmpty {
                                    Text(contact.phoneNumbers.first?.value.stringValue ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Footer buttons
            Divider()
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
            }
            .padding(12)
        }
        .frame(width: 400, height: 500)
    }

    private var filteredContacts: [CNContact] {
        if searchText.isEmpty {
            return contacts
        } else {
            return contacts.filter { contact in
                let fullName = "\(contact.givenName) \(contact.familyName)".lowercased()
                return fullName.contains(searchText.lowercased())
            }
        }
    }

    private func loadContacts() {
        isLoading = true

        // Create a new CNContactStore
        let store = CNContactStore()

        Task.detached {
            do {
                // Try to fetch contacts - this will trigger permission dialog if needed
                let keysToFetch = [
                    CNContactGivenNameKey,
                    CNContactFamilyNameKey,
                    CNContactPhoneNumbersKey,
                    CNContactEmailAddressesKey
                ] as [CNKeyDescriptor]

                let request = CNContactFetchRequest(keysToFetch: keysToFetch)

                // Enumerate on background thread to avoid UI unresponsiveness
                let fetchedContacts = try await Task.detached {
                    var allContacts: [CNContact] = []
                    try store.enumerateContacts(with: request) { contact, _ in
                        allContacts.append(contact)
                    }
                    return allContacts
                }.value

                await MainActor.run {
                    self.contacts = fetchedContacts.sorted { $0.givenName < $1.givenName }
                    self.isLoading = false
                    self.permissionDenied = false
                }
            } catch let error as NSError {
                await MainActor.run {
                    self.permissionDenied = true
                    self.isLoading = false
                }
            }
        }
    }

}

struct MacContactPickerButton: View {
    @Binding var selectedContact: CNContact?
    @State private var showPicker = false

    var body: some View {
        Button(action: { showPicker = true }) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 20))
        }
        .popover(isPresented: $showPicker) {
            MacContactPickerView(selectedContact: $selectedContact)
        }
    }
}
#endif
