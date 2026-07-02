//
//  CreateReminderIntent.swift
//  QuickReminders
//
//  Siri integration for creating reminders with natural language (iOS only)
//

#if os(iOS)
import Foundation
import AppIntents
import EventKit

// MARK: - Create Reminder Intent
@available(iOS 16.0, *)
struct CreateReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Reminder"
    static var description = IntentDescription("Create a reminder with natural language")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Reminder Text")
    var reminderText: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Create \(\.$reminderText)")
    }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Request reminder text if not provided
        let text: String
        if let reminderText = reminderText {
            text = reminderText
        } else {
            text = try await $reminderText.requestValue("What would you like to be reminded about?")
        }

        // Parse the reminder text (with word number conversion for Siri)
        let colorTheme = SharedColorThemeManager()
        let parser = SharedNLParser(colorTheme: colorTheme)
        let parsed = parser.parseReminderText(text, convertWordNumbers: true)

        guard parsed.isValid else {
            return .result(dialog: IntentDialog("Sorry, I couldn't understand that reminder. Please try again."))
        }

        // Create the reminder using EventKit
        let eventStore = EKEventStore()

        // Request permissions (use new iOS 17+ API)
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = try await withCheckedThrowingContinuation { continuation in
                eventStore.requestFullAccessToReminders { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        } else {
            granted = try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }

        guard granted else {
            return .result(dialog: IntentDialog("Please grant QuickReminders access to Reminders in Settings."))
        }

        // Create the reminder (allow duplicates - no checking)
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = parsed.title

        if let dueDate = parsed.dueDate {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = components
        }

        // Handle recurring reminders
        if parsed.isRecurring,
           let frequency = parsed.recurrenceFrequency,
           let interval = parsed.recurrenceInterval {
            let rule = EKRecurrenceRule(
                recurrenceWith: frequency,
                interval: interval,
                end: parsed.recurrenceEndDate != nil ? EKRecurrenceEnd(end: parsed.recurrenceEndDate!) : nil
            )
            reminder.recurrenceRules = [rule]
        }

        // Get calendar - Use Siri default list if enabled, otherwise use app's selected list
        let sharedDefaults = UserDefaults(suiteName: "group.com.martinkostelka.QuickReminders") ?? UserDefaults.standard
        let calendar: EKCalendar

        // Check if Siri integration is enabled and has a default list set
        let siriEnabled = sharedDefaults.object(forKey: "SiriIntegrationEnabled") as? Bool ?? true
        if siriEnabled,
           let siriListID = sharedDefaults.string(forKey: "SiriDefaultList"),
           !siriListID.isEmpty,
           let siriList = eventStore.calendars(for: .reminder).first(where: { $0.calendarIdentifier == siriListID }) {
            calendar = siriList
        } else if let savedListID = sharedDefaults.string(forKey: "SelectedListIdentifier"),
                  let savedList = eventStore.calendars(for: .reminder).first(where: { $0.calendarIdentifier == savedListID }) {
            calendar = savedList
        } else {
            calendar = eventStore.defaultCalendarForNewReminders() ?? eventStore.calendars(for: .reminder).first!
        }

        reminder.calendar = calendar

        // Save the reminder
        try eventStore.save(reminder, commit: true)

        // Create a user-friendly response
        let response: String
        if let dueDate = parsed.dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            response = "Created reminder '\(parsed.title)' for \(formatter.string(from: dueDate))"
        } else {
            response = "Created reminder '\(parsed.title)'"
        }

        // Ask if user wants to continue (this keeps Siri listening!)
        let wantsToContinue = try await $reminderText.requestValue(IntentDialog(stringLiteral: "\(response). Want to do another task? Say 'yes' to continue or 'no' to finish."))

        if wantsToContinue.lowercased().contains("yes") || wantsToContinue.lowercased().contains("sure") || wantsToContinue.lowercased().contains("yeah") {
            return .result(dialog: IntentDialog("Great! Say 'Create a reminder in QuickReminders', 'Move reminder in QuickReminders', or 'Remove reminder in QuickReminders' to continue."))
        } else {
            return .result(dialog: IntentDialog("All done!"))
        }
    }
}

// MARK: - Helper Function for Parsing User Selection
@available(iOS 16.0, *)
func parseSelection(_ response: String, maxCount: Int) -> Int {
    let lowercased = response.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

    // Try to parse as a number directly ("1", "2", "3", etc.)
    if let number = Int(lowercased), number >= 1 && number <= maxCount {
        return number - 1 // Convert to 0-indexed
    }

    // Handle word numbers
    let wordNumbers: [String: Int] = [
        "first": 0, "one": 0, "1st": 0,
        "second": 1, "two": 1, "2nd": 1,
        "third": 2, "three": 2, "3rd": 2,
        "fourth": 3, "four": 3, "4th": 3,
        "fifth": 4, "five": 4, "5th": 4
    ]

    for (word, index) in wordNumbers {
        if lowercased.contains(word) && index < maxCount {
            return index
        }
    }

    // Default to invalid
    return -1
}

// MARK: - Helper Functions for Smart Duplicate Filtering
@available(iOS 16.0, *)
extension Array where Element == EKReminder {
    func filterByDateQualifier(_ searchTerm: String) -> [EKReminder] {
        let lowercaseSearch = searchTerm.lowercased()

        // Check for "no date" qualifiers
        let noDateKeywords = ["no date", "without date", "no due date", "without a date"]
        for keyword in noDateKeywords {
            if lowercaseSearch.contains(keyword) {
                return self.filter { $0.dueDateComponents == nil }
            }
        }

        // Check for weekday qualifiers (on monday, on sunday, just "monday", etc.)
        let weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
                       "mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        for weekday in weekdays {
            if lowercaseSearch.contains(weekday) {
                return self.filter { reminder in
                    guard let date = reminder.dueDateComponents?.date else { return false }
                    let calendar = Calendar.current
                    let weekdayComponent = calendar.component(.weekday, from: date)
                    let dayName = calendar.weekdaySymbols[weekdayComponent - 1].lowercased()
                    let shortDayName = calendar.shortWeekdaySymbols[weekdayComponent - 1].lowercased()
                    return dayName.contains(weekday) || shortDayName.contains(weekday)
                }
            }
        }

        // Check for "tomorrow" or "today"
        if lowercaseSearch.contains("tomorrow") {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            return self.filter { reminder in
                guard let date = reminder.dueDateComponents?.date else { return false }
                return Calendar.current.isDate(date, inSameDayAs: tomorrow)
            }
        }

        if lowercaseSearch.contains("today") {
            return self.filter { reminder in
                guard let date = reminder.dueDateComponents?.date else { return false }
                return Calendar.current.isDateInToday(date)
            }
        }

        // No date qualifier found, return all
        return self
    }
}

// MARK: - Move Reminder Intent
@available(iOS 16.0, *)
struct MoveReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Move Reminder"
    static var description = IntentDescription("Move a reminder to a different date")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Search Term")
    var searchTerm: String?

    @Parameter(title: "New Date")
    var newDateText: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Move \(\.$searchTerm) to \(\.$newDateText)")
    }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Request search term if not provided
        let search: String
        if let searchTerm = searchTerm {
            search = searchTerm
        } else {
            search = try await $searchTerm.requestValue("Which reminder do you want to move?")
        }

        let eventStore = EKEventStore()

        // Request permissions
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = try await withCheckedThrowingContinuation { continuation in
                eventStore.requestFullAccessToReminders { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        } else {
            granted = try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }

        guard granted else {
            return .result(dialog: IntentDialog("Please grant QuickReminders access to Reminders in Settings."))
        }

        // Search for the reminder
        let allReminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            let predicate = eventStore.predicateForReminders(in: nil)
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        // First, filter by title (searching for base title, ignoring date qualifiers)
        var matchingReminders = allReminders.filter { reminder in
            reminder.title?.lowercased().contains(search.lowercased()) == true
        }

        // If no matches found, try extracting just the title part (remove date qualifiers)
        if matchingReminders.isEmpty {
            // Remove common date qualifier words to get base title
            let dateKeywords = ["on", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
                               "mon", "tue", "wed", "thu", "fri", "sat", "sun",
                               "tomorrow", "today", "no date", "without date", "the one", "one"]
            var baseSearch = search.lowercased()
            for keyword in dateKeywords {
                baseSearch = baseSearch.replacingOccurrences(of: keyword, with: "")
            }
            baseSearch = baseSearch.trimmingCharacters(in: .whitespacesAndNewlines)

            if !baseSearch.isEmpty {
                matchingReminders = allReminders.filter { reminder in
                    reminder.title?.lowercased().contains(baseSearch) == true
                }
            }
        }

        // If still no matches, ask user to clarify the reminder name
        if matchingReminders.isEmpty {
            let clarification = try await $searchTerm.requestValue(IntentDialog(stringLiteral: "I couldn't find a reminder called '\(search)'. What's the exact name of the reminder you want to move?"))

            // Search again with clarified term
            matchingReminders = allReminders.filter { reminder in
                reminder.title?.lowercased().contains(clarification.lowercased()) == true
            }

            // If STILL no matches after clarification, give up
            guard !matchingReminders.isEmpty else {
                return .result(dialog: IntentDialog("I still couldn't find a reminder matching '\(clarification)'. Please check your reminders and try again."))
            }
        }

        // Apply date qualifier filtering if multiple matches found
        if matchingReminders.count > 1 {
            let dateFiltered = matchingReminders.filterByDateQualifier(search)
            if !dateFiltered.isEmpty {
                matchingReminders = dateFiltered
            }
        }

        // If still multiple matches after filtering, ask user to choose
        let reminderToMove: EKReminder
        if matchingReminders.count > 1 {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short

            var descriptions: [String] = []
            for (index, reminder) in matchingReminders.prefix(5).enumerated() {
                let title = reminder.title ?? "Untitled"
                if let date = reminder.dueDateComponents?.date {
                    descriptions.append("\(index + 1). '\(title)' on \(formatter.string(from: date))")
                } else {
                    descriptions.append("\(index + 1). '\(title)' (no date)")
                }
            }

            let list = descriptions.joined(separator: "\n")
            let selectionPrompt = "I found \(matchingReminders.count) reminders:\n\n\(list)\n\nWhich one do you want to move? Say the number."

            var selectionResponse = try await $searchTerm.requestValue(IntentDialog(stringLiteral: selectionPrompt))

            // Parse selection (could be "1", "2", "first", "second", "the first one", etc.)
            var selectedIndex = parseSelection(selectionResponse, maxCount: matchingReminders.count)

            // If invalid, ask them to repeat
            if selectedIndex < 0 || selectedIndex >= matchingReminders.count {
                selectionResponse = try await $searchTerm.requestValue(IntentDialog(stringLiteral: "Sorry, I didn't catch that. Which number? Say 1, 2, 3, etc."))
                selectedIndex = parseSelection(selectionResponse, maxCount: matchingReminders.count)

                // If STILL invalid after retry, give up
                guard selectedIndex >= 0 && selectedIndex < matchingReminders.count else {
                    return .result(dialog: IntentDialog("I still didn't understand. Please try the whole command again."))
                }
            }

            reminderToMove = matchingReminders[selectedIndex]
        } else {
            reminderToMove = matchingReminders[0]
        }

        // Request new date if not provided
        let dateText: String
        if let newDateText = newDateText {
            dateText = newDateText
        } else {
            dateText = try await $newDateText.requestValue("When should I move it to?")
        }

        // Parse the new date (with word number conversion for Siri)
        let colorTheme = SharedColorThemeManager()
        let parser = SharedNLParser(colorTheme: colorTheme)
        let parsed = parser.parseReminderText("dummy \(dateText)", convertWordNumbers: true) // Add dummy title to parse date

        guard let newDate = parsed.dueDate else {
            return .result(dialog: IntentDialog("I couldn't understand the date '\(dateText)'. Please try again."))
        }

        // DIFFERENT APPROACH: Create a NEW reminder with updated date, delete old one
        // This is more reliable than modifying existing reminder

        let newReminder = EKReminder(eventStore: eventStore)
        newReminder.title = reminderToMove.title
        newReminder.notes = reminderToMove.notes
        newReminder.calendar = reminderToMove.calendar

        // Set the new date
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: newDate)
        newReminder.dueDateComponents = components

        // Copy recurrence rules if any
        if let recurrenceRules = reminderToMove.recurrenceRules {
            newReminder.recurrenceRules = recurrenceRules
        }

        // Copy priority
        newReminder.priority = reminderToMove.priority

        // Save the NEW reminder first
        do {
            try eventStore.save(newReminder, commit: false)
        } catch let error as NSError {
            return .result(dialog: IntentDialog("Failed to create new reminder: \(error.localizedDescription)"))
        }

        // Delete the OLD reminder
        do {
            try eventStore.remove(reminderToMove, commit: false)
        } catch let error as NSError {
            return .result(dialog: IntentDialog("Failed to remove old reminder: \(error.localizedDescription)"))
        }

        // NOW commit both changes at once
        do {
            try eventStore.commit()
        } catch let error as NSError {
            return .result(dialog: IntentDialog("Failed to commit changes: \(error.localizedDescription)"))
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        // Ask if user wants to continue (this keeps Siri listening!)
        let wantsToContinue = try await $searchTerm.requestValue(IntentDialog(stringLiteral: "Moved '\(newReminder.title ?? "reminder")' to \(formatter.string(from: newDate)). Want to do another task? Say 'yes' to continue or 'no' to finish."))

        if wantsToContinue.lowercased().contains("yes") || wantsToContinue.lowercased().contains("sure") || wantsToContinue.lowercased().contains("yeah") {
            return .result(dialog: IntentDialog("Great! Say 'Create a reminder in QuickReminders', 'Move reminder in QuickReminders', or 'Remove reminder in QuickReminders' to continue."))
        } else {
            return .result(dialog: IntentDialog("All done!"))
        }
    }
}

// MARK: - Remove Reminder Intent
@available(iOS 16.0, *)
struct RemoveReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Remove Reminder"
    static var description = IntentDescription("Delete a reminder")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Search Term")
    var searchTerm: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Remove \(\.$searchTerm)")
    }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Request search term if not provided
        let search: String
        if let searchTerm = searchTerm {
            search = searchTerm
        } else {
            search = try await $searchTerm.requestValue("Which reminder do you want to remove?")
        }

        let eventStore = EKEventStore()

        // Request permissions
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = try await withCheckedThrowingContinuation { continuation in
                eventStore.requestFullAccessToReminders { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        } else {
            granted = try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }

        guard granted else {
            return .result(dialog: IntentDialog("Please grant QuickReminders access to Reminders in Settings."))
        }

        // Search for the reminder
        let allReminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            let predicate = eventStore.predicateForReminders(in: nil)
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        // First, filter by title (searching for base title, ignoring date qualifiers)
        var matchingReminders = allReminders.filter { reminder in
            reminder.title?.lowercased().contains(search.lowercased()) == true
        }

        // If no matches found, try extracting just the title part (remove date qualifiers)
        if matchingReminders.isEmpty {
            // Remove common date qualifier words to get base title
            let dateKeywords = ["on", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
                               "mon", "tue", "wed", "thu", "fri", "sat", "sun",
                               "tomorrow", "today", "no date", "without date", "the one", "one"]
            var baseSearch = search.lowercased()
            for keyword in dateKeywords {
                baseSearch = baseSearch.replacingOccurrences(of: keyword, with: "")
            }
            baseSearch = baseSearch.trimmingCharacters(in: .whitespacesAndNewlines)

            if !baseSearch.isEmpty {
                matchingReminders = allReminders.filter { reminder in
                    reminder.title?.lowercased().contains(baseSearch) == true
                }
            }
        }

        // If still no matches, ask user to clarify the reminder name
        if matchingReminders.isEmpty {
            let clarification = try await $searchTerm.requestValue(IntentDialog(stringLiteral: "I couldn't find a reminder called '\(search)'. What's the exact name of the reminder you want to remove?"))

            // Search again with clarified term
            matchingReminders = allReminders.filter { reminder in
                reminder.title?.lowercased().contains(clarification.lowercased()) == true
            }

            // If STILL no matches after clarification, give up
            guard !matchingReminders.isEmpty else {
                return .result(dialog: IntentDialog("I still couldn't find a reminder matching '\(clarification)'. Please check your reminders and try again."))
            }
        }

        // Apply date qualifier filtering if multiple matches found
        if matchingReminders.count > 1 {
            let dateFiltered = matchingReminders.filterByDateQualifier(search)
            if !dateFiltered.isEmpty {
                matchingReminders = dateFiltered
            }
        }

        // If still multiple matches after filtering, ask user to choose
        let reminderToRemove: EKReminder
        if matchingReminders.count > 1 {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short

            var descriptions: [String] = []
            for (index, reminder) in matchingReminders.prefix(5).enumerated() {
                let title = reminder.title ?? "Untitled"
                if let date = reminder.dueDateComponents?.date {
                    descriptions.append("\(index + 1). '\(title)' on \(formatter.string(from: date))")
                } else {
                    descriptions.append("\(index + 1). '\(title)' (no date)")
                }
            }

            let list = descriptions.joined(separator: "\n")
            let selectionPrompt = "I found \(matchingReminders.count) reminders:\n\n\(list)\n\nWhich one do you want to remove? Say the number."

            var selectionResponse = try await $searchTerm.requestValue(IntentDialog(stringLiteral: selectionPrompt))

            // Parse selection (could be "1", "2", "first", "second", "the first one", etc.)
            var selectedIndex = parseSelection(selectionResponse, maxCount: matchingReminders.count)

            // If invalid, ask them to repeat
            if selectedIndex < 0 || selectedIndex >= matchingReminders.count {
                selectionResponse = try await $searchTerm.requestValue(IntentDialog(stringLiteral: "Sorry, I didn't catch that. Which number? Say 1, 2, 3, etc."))
                selectedIndex = parseSelection(selectionResponse, maxCount: matchingReminders.count)

                // If STILL invalid after retry, give up
                guard selectedIndex >= 0 && selectedIndex < matchingReminders.count else {
                    return .result(dialog: IntentDialog("I still didn't understand. Please try the whole command again."))
                }
            }

            reminderToRemove = matchingReminders[selectedIndex]
        } else {
            reminderToRemove = matchingReminders[0]
        }
        let reminderTitle = reminderToRemove.title ?? "reminder"

        // Delete the reminder
        try eventStore.remove(reminderToRemove, commit: true)

        // Ask if user wants to continue (this keeps Siri listening!)
        let wantsToContinue = try await $searchTerm.requestValue(IntentDialog(stringLiteral: "Removed '\(reminderTitle)'. Want to do another task? Say 'yes' to continue or 'no' to finish."))

        if wantsToContinue.lowercased().contains("yes") || wantsToContinue.lowercased().contains("sure") || wantsToContinue.lowercased().contains("yeah") {
            return .result(dialog: IntentDialog("Great! Say 'Create a reminder in QuickReminders', 'Move reminder in QuickReminders', or 'Remove reminder in QuickReminders' to continue."))
        } else {
            return .result(dialog: IntentDialog("All done!"))
        }
    }
}

// MARK: - Simple Open App Intent (for Control Widget)
@available(iOS 18.0, *)
struct OpenQuickRemindersIntent: AppIntent {
    static var title: LocalizedStringResource = "Open QuickReminders"
    static var description = IntentDescription("Opens QuickReminders app")

    static var openAppWhenRun: Bool = true

    init() {}

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - App Shortcuts Provider
@available(iOS 16.0, *)
struct QuickRemindersShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateReminderIntent(),
            phrases: [
                "Create a reminder in \(.applicationName)",
                "Add reminder in \(.applicationName)",
                "Remind me in \(.applicationName)",
                "Set a reminder in \(.applicationName)",
                "Create \(.applicationName) reminder"
            ],
            shortTitle: "Create Reminder",
            systemImageName: "bell.badge.fill"
        )
        AppShortcut(
            intent: MoveReminderIntent(),
            phrases: [
                "Move reminder in \(.applicationName)",
                "Reschedule reminder in \(.applicationName)",
                "Change reminder date in \(.applicationName)"
            ],
            shortTitle: "Move Reminder",
            systemImageName: "arrow.right.circle.fill"
        )
        AppShortcut(
            intent: RemoveReminderIntent(),
            phrases: [
                "Remove reminder in \(.applicationName)",
                "Delete reminder in \(.applicationName)",
                "Cancel reminder in \(.applicationName)"
            ],
            shortTitle: "Remove Reminder",
            systemImageName: "trash.fill"
        )
    }
}
#endif
