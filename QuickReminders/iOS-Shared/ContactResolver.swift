//
//  ContactResolver.swift
//  QuickReminders
//
//  Contact resolution system for natural language parsing and UI picker
//

import Foundation
import Contacts
import Combine

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public class ContactResolver: ObservableObject {
    @Published public var hasPermission = false

    private let contactStore = CNContactStore()

    public init() {
        checkPermission()
    }

    public func requestPermission() async -> Bool {
        do {
            let granted = try await contactStore.requestAccess(for: .contacts)
            await MainActor.run {
                hasPermission = granted
            }
            return granted
        } catch {
            return false
        }
    }

    private func checkPermission() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        hasPermission = (status == .authorized)
    }

    // Parse contact names from text
    public func findContactNames(in text: String) -> [(name: String, range: NSRange)] {
        var results: [(String, NSRange)] = []

        // Common patterns: "call John", "meet with Sarah", "text Mom"
        let patterns = [
            "(?:call|text|meet with|email|message|contact)\\s+([A-Z][a-z]+(?:\\s+[A-Z][a-z]+)?)",
            "with\\s+([A-Z][a-z]+(?:\\s+[A-Z][a-z]+)?)",
            "(?:tell|remind|ask)\\s+([A-Z][a-z]+(?:\\s+[A-Z][a-z]+)?)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                for match in matches where match.numberOfRanges > 1 {
                    let nameRange = match.range(at: 1)
                    if let range = Range(nameRange, in: text) {
                        let name = String(text[range])
                        results.append((name, nameRange))
                    }
                }
            }
        }

        return results
    }

    // Search contacts by name
    public func searchContacts(matching name: String) async -> [CNContact] {
        guard hasPermission else { return [] }

        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactIdentifierKey
        ] as [CNKeyDescriptor]

        let predicate = CNContact.predicateForContacts(matchingName: name)

        do {
            return try contactStore.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
        } catch {
            return []
        }
    }

    // Get all contacts for picker
    public func getAllContacts() async -> [CNContact] {
        guard hasPermission else { return [] }

        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactIdentifierKey
        ] as [CNKeyDescriptor]

        let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
        fetchRequest.sortOrder = .givenName

        var contacts: [CNContact] = []

        do {
            try contactStore.enumerateContacts(with: fetchRequest) { contact, _ in
                contacts.append(contact)
            }
        } catch {
            // Silently handle contact fetch errors
        }

        return contacts
    }
}
