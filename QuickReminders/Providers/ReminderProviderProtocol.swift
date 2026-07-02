//
//  ReminderProviderProtocol.swift
//  QuickReminders
//
//  Universal protocol for reminder providers (Apple, Google, etc.)
//

#if os(iOS) || os(watchOS)
import Foundation

// MARK: - Universal Reminder Model

struct UniversalReminder: Identifiable {
    let id: String
    let title: String
    let notes: String?
    let dueDate: Date?
    let isCompleted: Bool
    let isRecurring: Bool

    // Track which service stores this reminder
    let storageType: ReminderStorageType
    let listId: String?
    let listName: String?
}

enum ReminderStorageType: String, Codable {
    case googleTasks = "tasks"
    case googleCalendar = "calendar"
    case appleReminders = "apple"
}

// MARK: - Provider Protocol

protocol ReminderProviderProtocol {
    var providerName: String { get }
    var isConnected: Bool { get }

    // Authentication
    func connect() async throws
    func disconnect()

    // Reminder CRUD
    func createReminder(
        title: String,
        notes: String?,
        dueDate: Date?,
        isRecurring: Bool,
        recurrenceRule: String?,
        listId: String?,
        contactIdentifier: String?,
        location: (name: String, latitude: Double, longitude: Double)?,
        isUrgent: Bool
    ) async throws -> UniversalReminder

    func fetchReminders() async throws -> [UniversalReminder]

    func moveReminder(
        id: String,
        storageType: ReminderStorageType,
        newDate: Date,
        listId: String?
    ) async throws

    func deleteReminder(
        id: String,
        storageType: ReminderStorageType,
        listId: String?
    ) async throws

    func completeReminder(
        id: String,
        storageType: ReminderStorageType,
        listId: String?,
        calendarCompletionMode: GoogleCalendarCompletionMode,
        currentTitle: String?
    ) async throws

    // Lists
    func fetchLists() async throws -> [(id: String, name: String)]
}

// MARK: - Provider Selection

enum ReminderProvider: String, Codable, CaseIterable {
    case apple = "Apple Reminders"
    case google = "Google (Tasks + Calendar)"

    var displayName: String {
        return self.rawValue
    }

    var description: String {
        switch self {
        case .apple:
            return "Full features, works offline, Siri integration"
        case .google:
            return "Sync with Google Tasks and Calendar"
        }
    }

    var limitations: [String] {
        switch self {
        case .apple:
            return []
        case .google:
            return [
                "Requires internet connection",
                "No location-based reminders"
            ]
        }
    }
}
#endif
