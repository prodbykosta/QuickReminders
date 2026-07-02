//
//  GoogleRemindersProvider.swift
//  QuickReminders
//
//  Smart hybrid provider: Uses Tasks for non-recurring, Calendar for recurring
//

#if os(iOS)
import Foundation
import Contacts

class GoogleRemindersProvider: ReminderProviderProtocol {
    var providerName: String { "Google (Tasks + Calendar)" }
    var isConnected: Bool { GoogleAuthManager.shared.isSignedIn }

    private let tasksService = GoogleTasksService()
    private let calendarService = GoogleCalendarService()
    private var defaultTaskListId: String?
    private var defaultCalendarId: String?

    // MARK: - Authentication

    func connect() async throws {
        guard GoogleAuthManager.shared.isSignedIn else {
            throw ProviderError.notConnected
        }

        // Get default task list
        let lists = try await fetchLists()
        defaultTaskListId = lists.first?.id
    }

    func disconnect() {
        GoogleAuthManager.shared.signOut()
        defaultTaskListId = nil
    }

    // MARK: - Create Reminder (SMART ROUTING!)

    func createReminder(
        title: String,
        notes: String?,
        dueDate: Date?,
        isRecurring: Bool,
        recurrenceRule: String?,
        listId: String?,
        contactIdentifier: String? = nil,
        location: (name: String, latitude: Double, longitude: Double)? = nil,
        isUrgent: Bool = false
    ) async throws -> UniversalReminder {

        // Build enriched description with contact/location metadata for Google
        var enrichedNotes = notes ?? ""

        if let contactID = contactIdentifier {
            // Find contact name from Contacts framework
            let contactStore = CNContactStore()
            if let contact = try? contactStore.unifiedContact(withIdentifier: contactID, keysToFetch: [CNContactGivenNameKey as CNKeyDescriptor, CNContactFamilyNameKey as CNKeyDescriptor]) {
                let contactName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                if !enrichedNotes.isEmpty { enrichedNotes += "\n\n" }
                enrichedNotes += "👤 Contact: \(contactName)"
            }
        }

        if let location = location {
            if !enrichedNotes.isEmpty { enrichedNotes += "\n" }
            enrichedNotes += "📍 Location: \(location.name)"
        }

        if isUrgent {
            if !enrichedNotes.isEmpty { enrichedNotes += "\n" }
            enrichedNotes += "🔴 URGENT"
        }

        if isRecurring {
            // RECURRING → Use Google Calendar
            return try await createCalendarReminder(
                title: title,
                notes: enrichedNotes.isEmpty ? nil : enrichedNotes,
                dueDate: dueDate,
                recurrenceRule: recurrenceRule,
                calendarId: defaultCalendarId
            )
        } else {
            // NON-RECURRING → Use Google Tasks
            return try await createTaskReminder(
                title: title,
                notes: enrichedNotes.isEmpty ? nil : enrichedNotes,
                dueDate: dueDate,
                listId: listId
            )
        }
    }

    // Additional method for custom calendar selection
    // ALWAYS creates in calendar (used when user explicitly selects calendar via bolt)
    func createReminderWithCalendar(
        title: String,
        notes: String?,
        dueDate: Date?,
        isRecurring: Bool,
        recurrenceRule: String?,
        listId: String?,
        calendarId: String?
    ) async throws -> UniversalReminder {

        // ALWAYS use calendar when this method is called
        return try await createCalendarReminder(
            title: title,
            notes: notes,
            dueDate: dueDate,
            recurrenceRule: recurrenceRule,
            calendarId: calendarId ?? defaultCalendarId
        )
    }

    // Method to set default calendar for recurring reminders
    func setDefaultCalendar(calendarId: String) {
        defaultCalendarId = calendarId
    }

    private func createTaskReminder(title: String, notes: String?, dueDate: Date?, listId: String?) async throws -> UniversalReminder {
        let targetList = listId ?? defaultTaskListId ?? ""
        let task = try await tasksService.createTask(title: title, notes: notes, dueDate: dueDate, in: targetList)

        return UniversalReminder(
            id: task.id,
            title: task.title,
            notes: task.notes,
            dueDate: task.dueDate,
            isCompleted: task.isCompleted,
            isRecurring: false,
            storageType: .googleTasks,
            listId: targetList,
            listName: nil
        )
    }

    private func createCalendarReminder(title: String, notes: String?, dueDate: Date?, recurrenceRule: String?, calendarId: String?) async throws -> UniversalReminder {
        let startDate = dueDate ?? Date()
        let event = try await calendarService.createEvent(
            title: title,
            notes: notes,
            startDate: startDate,
            recurrenceRule: recurrenceRule,
            calendarId: calendarId ?? defaultCalendarId
        )

        return UniversalReminder(
            id: event.id,
            title: event.summary ?? "Untitled Event",
            notes: event.description,
            dueDate: event.startDate,
            isCompleted: false,
            isRecurring: event.isRecurring,
            storageType: .googleCalendar,
            listId: nil,
            listName: "QuickReminders Calendar"
        )
    }

    // MARK: - Fetch Reminders (FROM BOTH!)

    func fetchReminders() async throws -> [UniversalReminder] {
        async let tasksReminders = fetchFromTasks()
        async let calendarReminders = fetchFromCalendar()

        // Fetch both in parallel, then merge
        let (tasks, events) = try await (tasksReminders, calendarReminders)
        return tasks + events
    }

    private func fetchFromTasks() async throws -> [UniversalReminder] {
        let lists = try await tasksService.fetchTaskLists()
        var allReminders: [UniversalReminder] = []

        for list in lists {
            let tasks = try await tasksService.fetchTasks(from: list.id)
            let reminders = tasks.map { task in
                UniversalReminder(
                    id: task.id,
                    title: task.title,
                    notes: task.notes,
                    dueDate: task.dueDate,
                    isCompleted: task.isCompleted,
                    isRecurring: false,  // Tasks are never recurring
                    storageType: .googleTasks,
                    listId: list.id,
                    listName: list.title
                )
            }
            allReminders.append(contentsOf: reminders)
        }

        return allReminders
    }

    private func fetchFromCalendar() async throws -> [UniversalReminder] {
        let eventsWithCalendars = try await calendarService.fetchEvents()

        // Filter out events without a title (birthdays, all-day events, etc.)
        return eventsWithCalendars.compactMap { item in
            guard let title = item.event.summary, !title.isEmpty else {
                return nil  // Skip events without titles
            }

            return UniversalReminder(
                id: item.event.id,
                title: title,
                notes: item.event.description,
                dueDate: item.event.startDate,
                isCompleted: false,  // Calendar events don't have completion
                isRecurring: item.event.isRecurring,
                storageType: .googleCalendar,
                listId: item.calendarId,  // Store the calendar ID for deletion/updates
                listName: item.calendarName
            )
        }
    }

    // MARK: - Move Reminder

    func moveReminder(
        id: String,
        storageType: ReminderStorageType,
        newDate: Date,
        listId: String?
    ) async throws {

        switch storageType {
        case .googleTasks:
            let targetList = listId ?? defaultTaskListId ?? ""
            try await tasksService.updateTask(taskId: id, in: targetList, newDate: newDate)

        case .googleCalendar:
            guard let calendarId = listId else {
                throw ProviderError.noDefaultList
            }
            try await calendarService.updateEvent(eventId: id, calendarId: calendarId, newDate: newDate)

        case .appleReminders:
            throw ProviderError.invalidStorageType
        }
    }

    // MARK: - Delete Reminder

    func deleteReminder(
        id: String,
        storageType: ReminderStorageType,
        listId: String?
    ) async throws {

        switch storageType {
        case .googleTasks:
            let targetList = listId ?? defaultTaskListId ?? ""
            try await tasksService.deleteTask(taskId: id, from: targetList)

        case .googleCalendar:
            guard let calendarId = listId else {
                throw ProviderError.noDefaultList
            }
            try await calendarService.deleteEvent(eventId: id, calendarId: calendarId)

        case .appleReminders:
            throw ProviderError.invalidStorageType
        }
    }

    // MARK: - Complete Reminder

    func completeReminder(
        id: String,
        storageType: ReminderStorageType,
        listId: String?,
        calendarCompletionMode: GoogleCalendarCompletionMode = .delete,
        currentTitle: String? = nil
    ) async throws {

        switch storageType {
        case .googleTasks:
            let targetList = listId ?? defaultTaskListId ?? ""
            try await tasksService.completeTask(taskId: id, in: targetList)

        case .googleCalendar:
            guard let calendarId = listId else {
                throw ProviderError.noDefaultList
            }

            // Handle completion based on user preference
            switch calendarCompletionMode {
            case .delete:
                // Delete the event (original behavior)
                try await calendarService.deleteEvent(eventId: id, calendarId: calendarId)

            case .rename:
                // Rename by adding " - COMPLETED" to the title
                guard let title = currentTitle else {
                    throw ProviderError.noDefaultList  // Using existing error for now
                }
                try await calendarService.renameEventAsCompleted(eventId: id, calendarId: calendarId, currentTitle: title)
            }

        case .appleReminders:
            throw ProviderError.invalidStorageType
        }
    }

    // MARK: - Fetch Lists

    func fetchLists() async throws -> [(id: String, name: String)] {
        let lists = try await tasksService.fetchTaskLists()
        return lists.map { (id: $0.id, name: $0.title) }
    }

    func fetchCalendars() async throws -> [(id: String, name: String)] {
        let calendars = try await calendarService.fetchAllCalendars()
        return calendars.map { (id: $0.id, name: $0.summary) }
    }
}

// MARK: - Errors

enum ProviderError: Error, LocalizedError {
    case notConnected
    case noDefaultList
    case invalidStorageType

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to provider"
        case .noDefaultList:
            return "No default list selected"
        case .invalidStorageType:
            return "Invalid storage type for this operation"
        }
    }
}
#endif
