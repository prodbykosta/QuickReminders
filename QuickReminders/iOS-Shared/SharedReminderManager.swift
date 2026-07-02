//
//  SharedReminderManager.swift
//  QuickReminders - Shared
//
//  Shared reminder management for macOS, iOS, and watchOS
//
#if os(iOS) || os(watchOS)
import Foundation
import EventKit
import Combine
import CoreLocation
import Contacts
import MapKit

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

// Lightweight list representation for UI
struct ReminderList: Identifiable, Equatable {
    let id: String
    let title: String
    let color: CGColor

    static func == (lhs: ReminderList, rhs: ReminderList) -> Bool {
        return lhs.id == rhs.id
    }
}

// Shared reminder manager for both platforms
class SharedReminderManager: ObservableObject {
    let eventStore = EKEventStore()
    @Published var hasAccess = false
    @Published var availableLists: [EKCalendar] = []
    @Published var selectedList: EKCalendar?

    // Google provider (iOS only)
    #if os(iOS) && !os(watchOS)
    private var googleProvider: GoogleRemindersProvider?
    #endif
    @Published var googleLists: [(id: String, name: String)] = []
    @Published var selectedGoogleListId: String?
    @Published var googleCalendars: [(id: String, name: String)] = []
    @Published var selectedGoogleCalendarId: String?

    let colorTheme: SharedColorThemeManager
    lazy var nlParser: SharedNLParser = {
        SharedNLParser(colorTheme: self.colorTheme)
    }()

    // Computed property to check which provider is active
    private var isUsingGoogle: Bool {
        #if os(iOS) && !os(watchOS)
        return colorTheme.selectedProvider == "Google (Tasks + Calendar)" && GoogleAuthManager.shared.isSignedIn
        #else
        return false  // watchOS doesn't support Google providers directly
        #endif
    }

    // Track which type is selected (for bolt display)
    @Published var googleSelectionType: GoogleSelectionType = .taskList

    enum GoogleSelectionType {
        case taskList
        case calendar
    }

    // Get the currently selected list name for UI display
    var currentListName: String {
        if isUsingGoogle {
            if googleSelectionType == .calendar {
                // Calendar is selected
                if let calendarId = selectedGoogleCalendarId,
                   let calendar = googleCalendars.first(where: { $0.id == calendarId }) {
                    return calendar.name
                }
                return "Calendar"
            } else {
                // Task list is selected
                if let listId = selectedGoogleListId,
                   let list = googleLists.first(where: { $0.id == listId }) {
                    return list.name
                }
                return "Google Tasks"
            }
        } else {
            return selectedList?.title ?? "Reminders"
        }
    }

    // Get the currently selected calendar name for UI display
    var currentCalendarName: String {
        if let calendarId = selectedGoogleCalendarId,
           let calendar = googleCalendars.first(where: { $0.id == calendarId }) {
            return calendar.name
        }
        return "Primary"
    }

    init(colorTheme: SharedColorThemeManager) {
        self.colorTheme = colorTheme

        #if os(iOS) && !os(watchOS)
        // Initialize Google provider (iOS only)
        googleProvider = GoogleRemindersProvider()
        #endif

        // Do permission checks asynchronously to avoid blocking
        Task { @MainActor in
            await checkCurrentAccessAsync()
            await requestAccessAsync()
        }

        // Observe provider changes
        colorTheme.$selectedProvider
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.reloadReminderLists()
                }
            }
            .store(in: &cancellables)

        #if os(iOS) && !os(watchOS)
        // Observe Google sign-in status (iOS only)
        GoogleAuthManager.shared.$isSignedIn
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.reloadReminderLists()
                }
            }
            .store(in: &cancellables)
        #endif
    }

    private var cancellables = Set<AnyCancellable>()
    
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
        if isUsingGoogle {
            #if os(iOS) && !os(watchOS)
            // Load Google Tasks lists and Calendars (iOS only)
            do {
                try await googleProvider?.connect()
                googleLists = try await googleProvider?.fetchLists() ?? []
                googleCalendars = try await googleProvider?.fetchCalendars() ?? []

                let sharedDefaults = UserDefaults(suiteName: "group.com.martinkostelka.QuickReminders") ?? UserDefaults.standard

                // Try to restore previously selected Google Task list
                if let savedListID = sharedDefaults.string(forKey: "SelectedGoogleListIdentifier"),
                   googleLists.contains(where: { $0.id == savedListID }) {
                    selectedGoogleListId = savedListID
                } else {
                    selectedGoogleListId = googleLists.first?.id
                }

                // Try to restore previously selected Google Calendar
                if let savedCalendarID = sharedDefaults.string(forKey: "SelectedGoogleCalendarIdentifier"),
                   googleCalendars.contains(where: { $0.id == savedCalendarID }) {
                    selectedGoogleCalendarId = savedCalendarID
                } else {
                    selectedGoogleCalendarId = googleCalendars.first?.id
                }

                // Restore selection type
                if let savedSelectionType = sharedDefaults.string(forKey: "GoogleSelectionType") {
                    googleSelectionType = savedSelectionType == "calendar" ? .calendar : .taskList
                } else {
                    googleSelectionType = .taskList  // Default to task list
                }
            } catch {
                googleLists = []
                googleCalendars = []
            }
            #endif
        } else {
            // Load Apple Reminders lists
            availableLists = eventStore.calendars(for: .reminder)

            // Try to restore previously selected list from App Group UserDefaults
            let sharedDefaults = UserDefaults(suiteName: "group.com.martinkostelka.QuickReminders") ?? UserDefaults.standard

            if let savedListID = sharedDefaults.string(forKey: "SelectedListIdentifier"),
               let savedList = availableLists.first(where: { $0.calendarIdentifier == savedListID }) {
                selectedList = savedList
            } else {
                selectedList = eventStore.defaultCalendarForNewReminders()
            }
        }
    }
    
    // Public method to reload lists (for settings)
    func reloadReminderLists() async {
        await loadReminderListsAsync()
    }
    
    // MARK: - Core Reminder Operations
    
    func createReminder(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        contactIdentifier: String? = nil,
        location: (name: String, latitude: Double, longitude: Double)? = nil,
        locationProximity: EKAlarmProximity = .enter,  // NEW: .enter (arriving) or .leave (leaving)
        isUrgent: Bool = false,
        alarmOffset: TimeInterval? = nil,
        isRecurring: Bool = false,  // NEW: Recurrence support
        recurrenceInterval: Int? = nil,  // NEW: Recurrence interval (e.g., 1, 2, 3...)
        recurrenceFrequency: EKRecurrenceFrequency? = nil,  // NEW: Recurrence frequency (.daily, .weekly, .monthly)
        recurrenceEndDate: Date? = nil,  // NEW: Optional end date for recurrence
        completion: @escaping (Bool, Error?) -> Void
    ) {
        #if os(iOS)
        guard hasAccess else {
            completion(false, ReminderError.accessDenied)
            return
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title

        // Build notes with contact info, urgent indicator, and user notes
        // (EventKit DOES NOT support contact identifiers on EKReminder!)
        var enrichedNotes = notes ?? ""

        // Add urgent indicator
        if isUrgent {
            if !enrichedNotes.isEmpty { enrichedNotes += "\n\n" }
            enrichedNotes += "⚠️ Urgent"
        }

        // Add contact info
        if let contactID = contactIdentifier {
            #if os(iOS)
            let contactStore = CNContactStore()
            if let contact = try? contactStore.unifiedContact(withIdentifier: contactID, keysToFetch: [CNContactGivenNameKey as CNKeyDescriptor, CNContactFamilyNameKey as CNKeyDescriptor]) {
                let contactName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                if !enrichedNotes.isEmpty { enrichedNotes += "\n\n" }
                enrichedNotes += "👤 Contact: \(contactName)"
            }
            #endif
        }
        reminder.notes = enrichedNotes.isEmpty ? nil : enrichedNotes

        if let dueDate = dueDate {
            let dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = dueDateComponents
        }

        // LOCATION-BASED REMINDER with geofencing (proper implementation!)
        if let location = location {
            let structuredLocation = EKStructuredLocation(title: location.name)
            let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            structuredLocation.geoLocation = clLocation
            structuredLocation.radius = 100.0 // 100 meters radius

            // Create location-based alarm with configurable proximity
            let locationAlarm = EKAlarm()
            locationAlarm.structuredLocation = structuredLocation
            locationAlarm.proximity = locationProximity // .enter (arriving) or .leave (leaving)
            reminder.addAlarm(locationAlarm)
        }

        // URGENT HANDLING - Set high priority to appear in "Urgent" smart list
        if isUrgent {
            reminder.priority = 1 // High priority (appears in iOS "Urgent" smart list)
        }

        // RECURRENCE HANDLING - Create recurrence rule if needed
        if isRecurring, let frequency = recurrenceFrequency {
            let interval = recurrenceInterval ?? 1

            let recurrenceRule = EKRecurrenceRule(
                recurrenceWith: frequency,
                interval: interval,
                end: recurrenceEndDate != nil ? EKRecurrenceEnd(end: recurrenceEndDate!) : nil
            )
            reminder.addRecurrenceRule(recurrenceRule)
        }

        reminder.calendar = selectedList ?? eventStore.defaultCalendarForNewReminders()

        do {
            try eventStore.save(reminder, commit: true)
            completion(true, nil)
        } catch {
            print("ERROR SharedReminderManager: Failed to save reminder: \(error)")
            completion(false, error)
        }
        #else
        // watchOS cannot save - this should not be called on watchOS
        completion(false, ReminderError.accessDenied)
        #endif
    }

    // NEW: Async overload for creating reminders with all new features
    func createReminder(
        from parsedReminder: SharedParsedReminder,
        selectedContact: CNContact?,
        selectedLocation: MKMapItem?,
        additionalNotes: String?
    ) async throws {
        #if os(iOS)
        // Extract contact identifier
        let contactID = selectedContact?.identifier ?? parsedReminder.contactIdentifier

        // Extract location data
        var locationData: (name: String, latitude: Double, longitude: Double)? = nil
        if let mapItem = selectedLocation {
            locationData = (
                name: mapItem.name ?? parsedReminder.locationName ?? "Unknown",
                latitude: mapItem.location.coordinate.latitude,
                longitude: mapItem.location.coordinate.longitude
            )
        } else if let coords = parsedReminder.locationCoordinates {
            locationData = (
                name: parsedReminder.locationName ?? "Unknown",
                latitude: coords.latitude,
                longitude: coords.longitude
            )
        }

        // Combine notes
        let finalNotes = [parsedReminder.notes, additionalNotes].compactMap { $0 }.joined(separator: "\n\n")

        // Check if using Google provider
        if isUsingGoogle {
            #if os(iOS) && !os(watchOS)
            guard let provider = googleProvider else {
                throw ReminderError.accessDenied
            }

            // Convert EKRecurrenceFrequency to recurrence rule string
            var recurrenceRule: String? = nil
            if parsedReminder.isRecurring {
                let freq: String
                switch parsedReminder.recurrenceFrequency {
                case .daily: freq = "DAILY"
                case .weekly: freq = "WEEKLY"
                case .monthly: freq = "MONTHLY"
                case .yearly: freq = "YEARLY"
                default: freq = "DAILY"
                }
                recurrenceRule = "RRULE:FREQ=\(freq);INTERVAL=\(parsedReminder.recurrenceInterval ?? 1)"
            }

            // Call Google provider with all new features
            _ = try await provider.createReminder(
                title: parsedReminder.title,
                notes: finalNotes.isEmpty ? nil : finalNotes,
                dueDate: parsedReminder.dueDate,
                isRecurring: parsedReminder.isRecurring,
                recurrenceRule: recurrenceRule,
                listId: selectedGoogleListId,
                contactIdentifier: contactID,
                location: locationData,
                isUrgent: parsedReminder.isUrgent
            )
            #endif
        } else {
            // Use Apple EventKit
            return try await withCheckedThrowingContinuation { continuation in
                createReminder(
                    title: parsedReminder.title,
                    notes: finalNotes.isEmpty ? nil : finalNotes,
                    dueDate: parsedReminder.dueDate,
                    contactIdentifier: contactID,
                    location: locationData,
                    locationProximity: parsedReminder.locationProximity,
                    isUrgent: parsedReminder.isUrgent,
                    alarmOffset: parsedReminder.alarmOffset,
                    isRecurring: parsedReminder.isRecurring,  // NEW: Pass recurrence flag
                    recurrenceInterval: parsedReminder.recurrenceInterval,  // NEW: Pass interval
                    recurrenceFrequency: parsedReminder.recurrenceFrequency,  // NEW: Pass frequency
                    recurrenceEndDate: parsedReminder.recurrenceEndDate  // NEW: Pass end date
                ) { success, error in
                    if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error ?? ReminderError.saveFailed)
                    }
                }
            }
        }
        #else
        throw ReminderError.accessDenied
        #endif
    }

    func createRecurringReminder(title: String, notes: String? = nil, startDate: Date, interval: Int, frequency: EKRecurrenceFrequency, endDate: Date? = nil, completion: @escaping (Bool, Error?) -> Void) {
        #if os(iOS)
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
        #else
        // watchOS cannot save - this should not be called on watchOS
        completion(false, ReminderError.accessDenied)
        #endif
    }

    func deleteReminder(_ reminder: EKReminder, completion: @escaping (Bool, Error?) -> Void) {
        #if os(iOS)
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
        #else
        // watchOS cannot save - this should not be called on watchOS
        completion(false, ReminderError.accessDenied)
        #endif
    }
    
    func getAllReminders(completion: @escaping ([EKReminder]) -> Void) {
        if isUsingGoogle {
            #if os(iOS) && !os(watchOS)
            // Fetch from Google - convert to completion handler (iOS only)
            Task {
                do {
                    _ = try await googleProvider?.fetchReminders() ?? []
                    // Convert UniversalReminder to EKReminder-compatible format for UI
                    // For now, just return empty since we need to refactor the UI
                    // TODO: Refactor commands to work with UniversalReminder
                    completion([])
                } catch {
                    completion([])
                }
            }
            #else
            completion([])
            #endif
        } else {
            guard hasAccess else {
                completion([])
                return
            }

            let predicate = eventStore.predicateForReminders(in: availableLists)
            eventStore.fetchReminders(matching: predicate) { reminders in
                completion(reminders ?? [])
            }
        }
    }
    
    func findReminder(withTitle title: String, completion: @escaping ([EKReminder]) -> Void) {
        if isUsingGoogle {
            // Not supported with Google yet - would need UI refactor
            completion([])
            return
        }

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

    // MARK: - Google Reminder Operations (iOS only)

    #if os(iOS) && !os(watchOS)
    func getAllGoogleReminders() async throws -> [UniversalReminder] {
        guard let provider = googleProvider else {
            throw ReminderError.accessDenied
        }
        return try await provider.fetchReminders()
    }

    func findGoogleReminder(withTitle title: String, allowDuplicates: Bool = false) async throws -> [UniversalReminder] {
        let allReminders = try await getAllGoogleReminders()
        let matching = allReminders.filter { reminder in
            reminder.title.lowercased().contains(title.lowercased())
        }

        if allowDuplicates || matching.count <= 1 {
            return matching
        }

        // Handle duplicates: group by title and select most recent (soonest due date) for each
        let grouped = Dictionary(grouping: matching) { $0.title.lowercased() }
        var result: [UniversalReminder] = []

        for (_, remindersWithSameTitle) in grouped {
            if remindersWithSameTitle.count == 1 {
                result.append(contentsOf: remindersWithSameTitle)
            } else {
                // Sort by due date (soonest first), nil dates go last
                let sorted = remindersWithSameTitle.sorted { r1, r2 in
                    let d1 = r1.dueDate ?? Date.distantFuture
                    let d2 = r2.dueDate ?? Date.distantFuture
                    return d1 < d2
                }
                if let first = sorted.first {
                    result.append(first)
                }
            }
        }

        return result
    }

    func deleteGoogleReminder(_ reminder: UniversalReminder) async throws {
        guard let provider = googleProvider else {
            throw ReminderError.accessDenied
        }
        try await provider.deleteReminder(
            id: reminder.id,
            storageType: reminder.storageType,
            listId: reminder.listId
        )
    }

    func moveGoogleReminder(_ reminder: UniversalReminder, to newDate: Date) async throws {
        guard let provider = googleProvider else {
            throw ReminderError.accessDenied
        }
        try await provider.moveReminder(
            id: reminder.id,
            storageType: reminder.storageType,
            newDate: newDate,
            listId: reminder.listId
        )
    }

    func completeGoogleReminder(_ reminder: UniversalReminder) async throws {
        guard let provider = googleProvider else {
            throw ReminderError.accessDenied
        }
        try await provider.completeReminder(
            id: reminder.id,
            storageType: reminder.storageType,
            listId: reminder.listId,
            calendarCompletionMode: colorTheme.googleCalendarCompletionMode,
            currentTitle: reminder.title
        )
    }
    #endif
    
    func moveReminder(_ reminder: EKReminder, to targetDate: Date, completion: @escaping (Bool, Error?) -> Void) {
        #if os(iOS)
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
        #else
        // watchOS cannot save - this should not be called on watchOS
        completion(false, ReminderError.accessDenied)
        #endif
    }

    // Save an existing reminder (for completing, etc.) - iOS only
    #if os(iOS)
    func saveReminder(_ reminder: EKReminder, completion: @escaping (Bool, Error?) -> Void) {
        guard hasAccess else {
            completion(false, ReminderError.accessDenied)
            return
        }

        do {
            try eventStore.save(reminder, commit: true)
            completion(true, nil)
        } catch {
            completion(false, error)
        }
    }
    #endif
    
    // MARK: - List Management

    func setSelectedList(_ list: EKCalendar) {
        selectedList = list

        // Save to shared UserDefaults for both platforms
        let sharedDefaults = UserDefaults(suiteName: "group.com.martinkostelka.QuickReminders") ?? UserDefaults.standard
        sharedDefaults.set(list.calendarIdentifier, forKey: "SelectedListIdentifier")
    }

    func setSelectedGoogleList(listId: String) {
        selectedGoogleListId = listId
        googleSelectionType = .taskList  // Switch to task list mode

        // Save to shared UserDefaults
        let sharedDefaults = UserDefaults(suiteName: "group.com.martinkostelka.QuickReminders") ?? UserDefaults.standard
        sharedDefaults.set(listId, forKey: "SelectedGoogleListIdentifier")
        sharedDefaults.set("taskList", forKey: "GoogleSelectionType")
    }

    func setSelectedGoogleCalendar(calendarId: String) {
        selectedGoogleCalendarId = calendarId
        googleSelectionType = .calendar  // Switch to calendar mode

        // Save to shared UserDefaults
        let sharedDefaults = UserDefaults(suiteName: "group.com.martinkostelka.QuickReminders") ?? UserDefaults.standard
        sharedDefaults.set(calendarId, forKey: "SelectedGoogleCalendarIdentifier")
        sharedDefaults.set("calendar", forKey: "GoogleSelectionType")
    }
    
    // MARK: - Helper Methods for Voice and Animation Integration (iOS only)

    #if os(iOS) && !os(watchOS)
    func createReminderWithAnimation(title: String, notes: String? = nil, dueDate: Date? = nil, animationManager: AnimationManager, completion: @escaping (Bool, Error?) -> Void = { _, _ in }) {
        animationManager.showCreatingReminder()

        createReminder(title: title, notes: notes, dueDate: dueDate) { success, error in
            DispatchQueue.main.async {
                if success {
                    animationManager.showReminderCreated()
                } else {
                    animationManager.showReminderCreationFailed(error?.localizedDescription)
                }
                completion(success, error)
            }
        }
    }

    func deleteReminderWithAnimation(_ reminder: EKReminder, animationManager: AnimationManager, completion: @escaping (Bool, Error?) -> Void = { _, _ in }) {
        animationManager.showDeletingReminder()

        deleteReminder(reminder) { success, error in
            DispatchQueue.main.async {
                if success {
                    animationManager.showReminderDeleted()
                } else {
                    let errorMsg = error?.localizedDescription ?? "Unknown error"
                    animationManager.showError("❌ Failed to delete: \(errorMsg)")
                }
                completion(success, error)
            }
        }
    }

    func moveReminderWithAnimation(_ reminder: EKReminder, to targetDate: Date, animationManager: AnimationManager, completion: @escaping (Bool, Error?) -> Void = { _, _ in }) {
        animationManager.showMovingReminder()

        moveReminder(reminder, to: targetDate) { success, error in
            DispatchQueue.main.async {
                if success {
                    animationManager.showReminderMoved()
                } else {
                    let errorMsg = error?.localizedDescription ?? "Unknown error"
                    animationManager.showError("❌ Failed to move: \(errorMsg)")
                }
                completion(success, error)
            }
        }
    }
    #endif

    func createReminder(from text: String) async throws {
        let parsed = nlParser.parseReminderText(text)

        guard parsed.isValid else {
            throw ReminderError.invalidInput
        }

        if isUsingGoogle {
            #if os(iOS) && !os(watchOS)
            // Use Google provider (iOS only)
            guard let provider = googleProvider else {
                throw ReminderError.accessDenied
            }

            do {
                // Convert EKRecurrenceFrequency to recurrence rule string for Google Calendar
                var recurrenceRule: String? = nil
                if parsed.isRecurring {
                    let freq: String
                    switch parsed.recurrenceFrequency {
                    case .daily: freq = "DAILY"
                    case .weekly: freq = "WEEKLY"
                    case .monthly: freq = "MONTHLY"
                    case .yearly: freq = "YEARLY"
                    default: freq = "DAILY"
                    }
                    recurrenceRule = "RRULE:FREQ=\(freq);INTERVAL=\(parsed.recurrenceInterval ?? 1)"
                }

                // SMART LOGIC based on what user selected via bolt
                if googleSelectionType == .calendar {
                    // User selected calendar
                    guard let calendarId = selectedGoogleCalendarId else {
                        throw ReminderError.invalidInput
                    }

                    // EXCEPTION: If no date, route to DEFAULT task list (can't add to calendar without date)
                    if parsed.dueDate == nil && !parsed.isRecurring {
                        _ = try await provider.createReminder(
                            title: parsed.title,
                            notes: nil,
                            dueDate: nil,
                            isRecurring: false,
                            recurrenceRule: nil,
                            listId: selectedGoogleListId
                        )
                    } else {
                        // Has date or recurring → Use selected calendar
                        provider.setDefaultCalendar(calendarId: calendarId)

                        _ = try await provider.createReminderWithCalendar(
                            title: parsed.title,
                            notes: nil,
                            dueDate: parsed.dueDate,
                            isRecurring: parsed.isRecurring,
                            recurrenceRule: recurrenceRule,
                            listId: selectedGoogleListId,
                            calendarId: calendarId
                        )
                    }
                } else {
                    // User selected a task list

                    // Check if has specific time (not midnight)
                    let hasSpecificTime: Bool = {
                        guard let date = parsed.dueDate else { return false }
                        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                        return components.hour != 0 || components.minute != 0
                    }()

                    if parsed.isRecurring || hasSpecificTime {
                        // EXCEPTION 1: Recurring always goes to DEFAULT calendar (Tasks don't support recurrence)
                        // EXCEPTION 2: Has time goes to DEFAULT calendar (Tasks can't store time)
                        guard let calendarId = selectedGoogleCalendarId else {
                            throw ReminderError.invalidInput
                        }

                        provider.setDefaultCalendar(calendarId: calendarId)

                        _ = try await provider.createReminderWithCalendar(
                            title: parsed.title,
                            notes: nil,
                            dueDate: parsed.dueDate,
                            isRecurring: parsed.isRecurring,
                            recurrenceRule: recurrenceRule,
                            listId: nil,
                            calendarId: calendarId
                        )
                    } else {
                        // Non-recurring without time → Use selected task list
                        _ = try await provider.createReminder(
                            title: parsed.title,
                            notes: nil,
                            dueDate: parsed.dueDate,
                            isRecurring: false,
                            recurrenceRule: nil,
                            listId: selectedGoogleListId
                        )
                    }
                }
            } catch {
                print("❌ Failed to create Google reminder: \(error)")
                print("   Error details: \(error.localizedDescription)")
                throw error
            }
            #else
            // watchOS doesn't support Google directly - would use WatchConnectivity
            throw ReminderError.accessDenied
            #endif
        } else {
            // Use Apple Reminders
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
}
#endif
