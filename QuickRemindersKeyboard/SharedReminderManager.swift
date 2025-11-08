//
//  SharedReminderManager.swift
//  QuickReminders - Shared
//
//  Shared reminder management for both macOS and iOS
//
#if os(iOS)
import Foundation
import EventKit
import Combine

// Shared ReminderError enum for both platforms
enum ReminderError: Error {
    case accessDenied
    case invalidInput
    case saveFailed
    
    var localizedDescription: String {
        switch self {
        case .accessDenied:
            return "Access to reminders is denied"
        case .invalidInput:
            return "Invalid reminder input"
        case .saveFailed:
            return "Failed to save reminder"
        }
    }
}

// Shared reminder manager for both platforms
class SharedReminderManager: ObservableObject {
    let eventStore = EKEventStore()
    @Published var hasAccess = false
    @Published var availableLists: [EKCalendar] = []
    @Published var selectedList: EKCalendar?
    
    let colorTheme: SharedColorThemeManager
    lazy var nlParser: SharedNLParser = {
        return SharedNLParser(colorTheme: self.colorTheme)
    }()
    
    init(colorTheme: SharedColorThemeManager) {
        self.colorTheme = colorTheme
        
        // Do permission checks asynchronously to avoid blocking
        Task { @MainActor in
            await checkCurrentAccessAsync()
            await requestAccessAsync()
        }
    }
    
    @MainActor
    private func checkCurrentAccessAsync() async {
        let currentStatus: EKAuthorizationStatus
        
        #if os(macOS)
        if #available(macOS 14.0, *) {
            currentStatus = EKEventStore.authorizationStatus(for: .reminder)
            hasAccess = currentStatus == .fullAccess
        } else {
            currentStatus = EKEventStore.authorizationStatus(for: .reminder)
            hasAccess = currentStatus == .authorized
        }
        #else
        // iOS
        if #available(iOS 17.0, *) {
            currentStatus = EKEventStore.authorizationStatus(for: .reminder)
            hasAccess = currentStatus == .fullAccess
        } else {
            currentStatus = EKEventStore.authorizationStatus(for: .reminder)
            hasAccess = currentStatus == .authorized
        }
        #endif
        
        if hasAccess {
            await loadReminderListsAsync()
        }
    }
    
    private func requestAccessAsync() async {
        let result: (Bool, Error?)
        
        #if os(macOS)
        if #available(macOS 14.0, *) {
            result = await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToReminders { granted, error in
                    continuation.resume(returning: (granted, error))
                }
            }
        } else {
            result = await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, error in
                    continuation.resume(returning: (granted, error))
                }
            }
        }
        #else
        // iOS
        if #available(iOS 17.0, *) {
            result = await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToReminders { granted, error in
                    continuation.resume(returning: (granted, error))
                }
            }
        } else {
            result = await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, error in
                    continuation.resume(returning: (granted, error))
                }
            }
        }
        #endif
        
        await MainActor.run {
            self.hasAccess = result.0
            
            if result.0 {
                Task {
                    await loadReminderListsAsync()
                }
            }
        }
    }
    
    func checkAccessStatus() {
        Task {
            await checkCurrentAccessAsync()
        }
    }
    
    func requestPermissionManually() {
        Task {
            await requestAccessAsync()
        }
    }
    
    @MainActor
    private func loadReminderListsAsync() async {
        availableLists = eventStore.calendars(for: .reminder)
        
        // Try to restore previously selected list from App Group UserDefaults
        let sharedDefaults = UserDefaults(suiteName: "group.com.martinkostelka.QuickReminders") ?? UserDefaults.standard
        
        if let savedListID = sharedDefaults.string(forKey: "SelectedListIdentifier") {
            if let savedList = availableLists.first(where: { $0.calendarIdentifier == savedListID }) {
                selectedList = savedList
            } else {
                selectedList = eventStore.defaultCalendarForNewReminders()
            }
        } else {
            selectedList = eventStore.defaultCalendarForNewReminders()
        }
    }
    
    // Public method to reload lists (for settings)
    func reloadReminderLists() async {
        await loadReminderListsAsync()
    }
    
    // MARK: - Core Reminder Operations
    
    func createReminder(title: String, notes: String? = nil, dueDate: Date? = nil, completion: @escaping (Bool, Error?) -> Void) {
        guard hasAccess else {
            completion(false, ReminderError.accessDenied)
            return
        }
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        
        if let dueDate = dueDate {
            let dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = dueDateComponents
        }
        
        reminder.calendar = selectedList ?? eventStore.defaultCalendarForNewReminders()
        
        do {
            try eventStore.save(reminder, commit: true)
            completion(true, nil)
        } catch {
            completion(false, error)
        }
    }
    
    func createRecurringReminder(title: String, notes: String? = nil, startDate: Date, interval: Int, frequency: EKRecurrenceFrequency, endDate: Date? = nil, completion: @escaping (Bool, Error?) -> Void) {
        guard hasAccess else {
            completion(false, ReminderError.accessDenied)
            return
        }
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        
        let startDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: startDate)
        reminder.dueDateComponents = startDateComponents
        
        let rule = EKRecurrenceRule(recurrenceWith: frequency, interval: interval, end: endDate != nil ? EKRecurrenceEnd(end: endDate!) : nil)
        reminder.recurrenceRules = [rule]
        
        reminder.calendar = selectedList ?? eventStore.defaultCalendarForNewReminders()
        
        do {
            try eventStore.save(reminder, commit: true)
            completion(true, nil)
        } catch {
            completion(false, error)
        }
    }
    
    func deleteReminder(_ reminder: EKReminder, completion: @escaping (Bool, Error?) -> Void) {
        guard hasAccess else {
            completion(false, ReminderError.accessDenied)
            return
        }
        
        do {
            try eventStore.remove(reminder, commit: true)
            completion(true, nil)
        } catch {
            completion(false, error)
        }
    }
    
    func completeReminder(_ reminder: EKReminder, completion: @escaping (Bool, Error?) -> Void) {
        guard hasAccess else {
            completion(false, ReminderError.accessDenied)
            return
        }
        
        reminder.isCompleted = true
        reminder.completionDate = Date()
        
        do {
            try eventStore.save(reminder, commit: true)
            completion(true, nil)
        } catch {
            completion(false, error)
        }
    }
    
    func getAllReminders(completion: @escaping ([EKReminder]) -> Void) {
        guard hasAccess else {
            completion([])
            return
        }
        
        let predicate = eventStore.predicateForReminders(in: availableLists)
        
        eventStore.fetchReminders(matching: predicate) { reminders in
            completion(reminders ?? [])
        }
    }
    
    func findReminder(withTitle title: String, completion: @escaping ([EKReminder]) -> Void) {
        guard hasAccess else {
            completion([])
            return
        }
        
        let predicate = eventStore.predicateForReminders(in: availableLists)
        eventStore.fetchReminders(matching: predicate) { reminders in
            let matchingReminders = reminders?.filter { reminder in
                reminder.title?.lowercased().contains(title.lowercased()) == true
            } ?? []
            completion(matchingReminders)
        }
    }
    
    func moveReminder(_ reminder: EKReminder, to targetDate: Date, completion: @escaping (Bool, Error?) -> Void) {
        guard hasAccess else {
            completion(false, ReminderError.accessDenied)
            return
        }
        
        let targetDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: targetDate)
        reminder.dueDateComponents = targetDateComponents
        
        do {
            try eventStore.save(reminder, commit: true)
            completion(true, nil)
        } catch {
            completion(false, error)
        }
    }
    
    // MARK: - List Management
    
    func setSelectedList(_ list: EKCalendar) {
        selectedList = list
        
        // Save to shared UserDefaults for both platforms
        let sharedDefaults = UserDefaults(suiteName: "group.com.martinkostelka.QuickReminders") ?? UserDefaults.standard
        sharedDefaults.set(list.calendarIdentifier, forKey: "SelectedListIdentifier")
    }
    
    // MARK: - Helper Methods for Voice and Animation Integration
    
    func createReminderWithAnimation(title: String, notes: String? = nil, dueDate: Date? = nil, completion: @escaping (Bool, Error?) -> Void = { _, _ in }) {
        createReminder(title: title, notes: notes, dueDate: dueDate) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    func deleteReminderWithAnimation(_ reminder: EKReminder, completion: @escaping (Bool, Error?) -> Void = { _, _ in }) {
        deleteReminder(reminder) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    func moveReminderWithAnimation(_ reminder: EKReminder, to targetDate: Date, completion: @escaping (Bool, Error?) -> Void = { _, _ in }) {
        moveReminder(reminder, to: targetDate) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    func completeReminderWithAnimation(_ reminder: EKReminder, completion: @escaping (Bool, Error?) -> Void = { _, _ in }) {
        completeReminder(reminder) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }

    func createReminder(from text: String) async throws {
        let parsed = nlParser.parseReminderText(text)

        guard parsed.isValid else {
            throw ReminderError.invalidInput
        }

        return try await withCheckedThrowingContinuation { continuation in
            if parsed.isRecurring {
                createRecurringReminder(
                    title: parsed.title,
                    startDate: parsed.dueDate ?? Date(),
                    interval: parsed.recurrenceInterval ?? 1,
                    frequency: parsed.recurrenceFrequency ?? .daily,
                    endDate: parsed.recurrenceEndDate
                ) { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            } else {
                createReminder(
                    title: parsed.title,
                    dueDate: parsed.dueDate
                ) { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
}
#endif
