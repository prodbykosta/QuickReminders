import Foundation
import EventKit
import Combine

class ReminderManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var hasAccess = false
    @Published var availableLists: [EKCalendar] = []
    @Published var selectedList: EKCalendar?
    
    // Reference to color theme for accessing default time setting
    weak var colorTheme: ColorThemeManager?
    
    init() {
        // Initialize ReminderManager
        
        // Do permission checks asynchronously to avoid blocking
        Task { @MainActor in
            await checkCurrentAccessAsync()
            await requestAccessAsync()
            // ReminderManager initialization complete
        }
    }
    
    @MainActor
    private func checkCurrentAccessAsync() async {
        // Check current reminder access
        
        let currentStatus: EKAuthorizationStatus
        if #available(macOS 14.0, *) {
            currentStatus = EKEventStore.authorizationStatus(for: .reminder)
            hasAccess = currentStatus == .fullAccess
        } else {
            currentStatus = EKEventStore.authorizationStatus(for: .reminder)
            hasAccess = currentStatus == .authorized
        }
        
        // Current authorization status checked
        
        if hasAccess {
            await loadReminderListsAsync()
        }
    }
    
    private func requestAccessAsync() async {
        // Request reminders access
        
        let result: (Bool, Error?)
        
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
        
        await MainActor.run {
            // Permission request completed
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
        // Manually request reminders permission
        
        Task {
            await requestAccessAsync()
        }
    }
    
    @MainActor
    private func loadReminderListsAsync() async {
        // Load reminder lists
        availableLists = eventStore.calendars(for: .reminder)
        
        // Try to restore previously selected list
        if let savedListID = UserDefaults.standard.string(forKey: "SelectedListIdentifier"),
           let savedList = availableLists.first(where: { $0.calendarIdentifier == savedListID }) {
            selectedList = savedList
            // Restored saved list
        } else {
            // Use default if no saved list
            selectedList = eventStore.defaultCalendarForNewReminders()
            // Using default reminder list
        }
        
        // Reminder lists loaded
    }
    
    // Public method to reload lists (for settings)
    func reloadReminderLists() async {
        await loadReminderListsAsync()
    }
    
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
        
        let dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: startDate)
        reminder.dueDateComponents = dueDateComponents
        
        // CRITICAL: For recurring reminders, BOTH startDateComponents AND dueDateComponents must be set
        reminder.startDateComponents = dueDateComponents
        
        // Set date components for recurring reminder
        
        // Create recurrence rule with optional end date
        var recurrenceEnd: EKRecurrenceEnd? = nil
        if let endDate = endDate {
            recurrenceEnd = EKRecurrenceEnd(end: endDate)
            // Setting recurrence end date
        }
        
        let recurrenceRule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            end: recurrenceEnd
        )
        
        // Created recurrence rule
        
        // CRITICAL: Set calendar BEFORE adding recurrence rule
        reminder.calendar = selectedList ?? eventStore.defaultCalendarForNewReminders()
        
        // Add the recurrence rule
        reminder.addRecurrenceRule(recurrenceRule)
        
        // Recurrence rule added to reminder
        
        do {
            try eventStore.save(reminder, commit: true)
            // Successfully saved recurring reminder to EventKit
            completion(true, nil)
        } catch {
            // Failed to save recurring reminder
            completion(false, error)
        }
    }
    
    func findReminder(withTitle title: String, searchOnlyCurrentList: Bool = false, completion: @escaping ([EKReminder]) -> Void) {
        guard hasAccess else {
            // No access to reminders
            completion([])
            return
        }
        
        // Determine which calendars to search based on scope setting
        let calendars: [EKCalendar]
        if searchOnlyCurrentList {
            if let currentList = selectedList {
                calendars = [currentList]
                // Searching only in current list
            } else {
                calendars = eventStore.calendars(for: .reminder)
                // No current list selected, searching all lists
            }
        } else {
            calendars = eventStore.calendars(for: .reminder)
            // Searching across all reminder lists
        }
        
        let predicate = eventStore.predicateForReminders(in: calendars)
        
        // Searching for reminder with title
        
        eventStore.fetchReminders(matching: predicate) { reminders in
            // Found total reminders
            
            let matchingReminders = self.smartReminderMatching(
                searchText: title,
                reminders: reminders ?? []
            )
            
            // Found matching reminders
            
            DispatchQueue.main.async {
                completion(matchingReminders)
            }
        }
    }
    
    // Enhanced search method that can handle time-specific reminders
    func findReminderWithTimeContext(searchText: String, searchOnlyCurrentList: Bool = false, completion: @escaping ([EKReminder]) -> Void) {
        guard hasAccess else {
            // No access to reminders
            completion([])
            return
        }
        
        // Determine which calendars to search based on scope setting
        let calendars: [EKCalendar]
        if searchOnlyCurrentList {
            if let currentList = selectedList {
                calendars = [currentList]
                // Time-context search only in current list
            } else {
                calendars = eventStore.calendars(for: .reminder)
                // Time-context search: No current list selected, searching all lists
            }
        } else {
            calendars = eventStore.calendars(for: .reminder)
            // Time-context search across all reminder lists
        }
        
        let predicate = eventStore.predicateForReminders(in: calendars)
        
        // Time-context search
        
        eventStore.fetchReminders(matching: predicate) { reminders in
            // Time-context search: Found total reminders
            
            let matchingReminders = self.timeSpecificReminderMatching(
                searchText: searchText,
                reminders: reminders ?? []
            )
            
            // Time-context search: Found matching reminders
            
            DispatchQueue.main.async {
                completion(matchingReminders)
            }
        }
    }
    
    // Smart reminder matching that can handle date/time qualifiers
    private func smartReminderMatching(searchText: String, reminders: [EKReminder]) -> [EKReminder] {
        let searchLower = searchText.lowercased()
        
        // Check if search contains date/time qualifiers
        let dateKeywords = ["on", "at", "tomorrow", "tm", "today", "td", "monday", "mon", "tuesday", "tue", "wednesday", "wed", 
                           "thursday", "thu", "friday", "fri", "saturday", "sat", "sunday", "sun", "next week", "next month"]
        
        let containsDateQualifier = dateKeywords.contains { keyword in
            searchLower.contains(" \(keyword) ") || searchLower.contains(" \(keyword)")
        }
        
        if containsDateQualifier {
            // Smart matching with date qualifier
            return smartMatchWithDateQualifier(searchText: searchLower, reminders: reminders)
        } else {
            // Regular title matching
            return simpleReminderMatching(searchText: searchLower, reminders: reminders)
        }
    }
    
    private func simpleReminderMatching(searchText: String, reminders: [EKReminder]) -> [EKReminder] {
        let titleMatches = reminders.filter { reminder in
            let reminderTitle = reminder.title?.lowercased() ?? ""
            return reminderTitle.contains(searchText)
        }
        
        // Found simple title matches
        
        // Handle identical names by selecting most recent
        return selectMostRecentForIdenticalNames(titleMatches)
    }
    
    private func smartMatchWithDateQualifier(searchText: String, reminders: [EKReminder]) -> [EKReminder] {
        // Parse the search text to extract title and date qualifier
        let parts = extractTitleAndDateQualifier(from: searchText)
        let titlePart = parts.title
        let dateQualifier = parts.dateQualifier
        
        // Smart search - extract title and date qualifier
        
        // First filter by title
        let titleMatches = reminders.filter { reminder in
            let reminderTitle = reminder.title?.lowercased() ?? ""
            return reminderTitle.contains(titlePart)
        }
        
        if titleMatches.count <= 1 {
            // Only one or no title match, returning
            return titleMatches
        }
        
        // Multiple matches, filter by date qualifier
        
        let dateFilteredMatches = titleMatches.filter { reminder in
            guard let dueDate = reminder.dueDateComponents?.date else {
                // Reminder has no due date
                return false
            }
            
            let matches = doesDateMatch(dueDate: dueDate, qualifier: dateQualifier)
            // Check if reminder date matches qualifier
            return matches
        }
        
        // Date-filtered matches
        return dateFilteredMatches.isEmpty ? titleMatches : dateFilteredMatches
    }
    
    private func extractTitleAndDateQualifier(from searchText: String) -> (title: String, dateQualifier: String) {
        let keywords = ["on", "at", "tomorrow", "tm", "today", "td", "monday", "mon", "tuesday", "tue", "wednesday", "wed", 
                       "thursday", "thu", "friday", "fri", "saturday", "sat", "sunday", "sun"]
        
        for keyword in keywords {
            if let keywordRange = searchText.range(of: " \(keyword) ") {
                let title = String(searchText[..<keywordRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let qualifier = String(searchText[keywordRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                return (title, "\(keyword) \(qualifier)")
            } else if searchText.hasSuffix(" \(keyword)") {
                let title = searchText.replacingOccurrences(of: " \(keyword)", with: "").trimmingCharacters(in: .whitespaces)
                return (title, keyword)
            }
        }
        
        return (searchText, "")
    }
    
    private func doesDateMatch(dueDate: Date, qualifier: String) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        
        // Handle time-based qualifiers (like "at 9am", "at 3pm")
        if qualifier.contains("at ") {
            return doesTimeMatch(dueDate: dueDate, qualifier: qualifier)
        }
        
        switch qualifier.lowercased() {
        case "today", "td":
            return calendar.isDate(dueDate, inSameDayAs: today)
        case "tomorrow", "tm":
            return calendar.isDate(dueDate, inSameDayAs: tomorrow)
        case let day where ["monday", "mon", "tuesday", "tue", "wednesday", "wed", "thursday", "thu", "friday", "fri", "saturday", "sat", "sunday", "sun"].contains(day):
            let weekdayNumber = weekdayNumber(for: day)
            let dueDateWeekday = calendar.component(.weekday, from: dueDate)
            return dueDateWeekday == weekdayNumber
        case let qualifier where qualifier.contains("friday") || qualifier.contains("fri"):
            return calendar.component(.weekday, from: dueDate) == 6 // Friday
        case let qualifier where qualifier.contains("monday") || qualifier.contains("mon"):
            return calendar.component(.weekday, from: dueDate) == 2 // Monday
        case let qualifier where qualifier.contains("tuesday") || qualifier.contains("tue"):
            return calendar.component(.weekday, from: dueDate) == 3 // Tuesday
        case let qualifier where qualifier.contains("wednesday") || qualifier.contains("wed"):
            return calendar.component(.weekday, from: dueDate) == 4 // Wednesday
        case let qualifier where qualifier.contains("thursday") || qualifier.contains("thu"):
            return calendar.component(.weekday, from: dueDate) == 5 // Thursday
        case let qualifier where qualifier.contains("saturday") || qualifier.contains("sat"):
            return calendar.component(.weekday, from: dueDate) == 7 // Saturday
        case let qualifier where qualifier.contains("sunday") || qualifier.contains("sun"):
            return calendar.component(.weekday, from: dueDate) == 1 // Sunday
        default:
            return false
        }
    }
    
    private func doesTimeMatch(dueDate: Date, qualifier: String) -> Bool {
        // Extract time from qualifier like "at 9am" or "at 3pm"
        let timePattern = "at (\\d{1,2})(am|pm|:\\d{2})"
        
        do {
            let regex = try NSRegularExpression(pattern: timePattern, options: .caseInsensitive)
            let matches = regex.matches(in: qualifier, options: [], range: NSRange(location: 0, length: qualifier.count))
            
            if let match = matches.first {
                let calendar = Calendar.current
                let dueHour = calendar.component(.hour, from: dueDate)
                
                // For now, do a simple hour match - this can be enhanced further
                let hourRange = match.range(at: 1)
                if let swiftRange = Range(hourRange, in: qualifier),
                   let searchHour = Int(String(qualifier[swiftRange])) {
                    
                    let isPM = qualifier.lowercased().contains("pm")
                    let adjustedSearchHour = isPM && searchHour != 12 ? searchHour + 12 : searchHour
                    
                    return abs(dueHour - adjustedSearchHour) <= 1 // Allow 1 hour tolerance
                }
            }
        } catch {
            // Time regex error
        }
        
        return false
    }
    
    private func weekdayNumber(for day: String) -> Int {
        switch day.lowercased() {
        case "sunday", "sun": return 1
        case "monday", "mon": return 2
        case "tuesday", "tue": return 3
        case "wednesday", "wed": return 4
        case "thursday", "thu": return 5
        case "friday", "fri": return 6
        case "saturday", "sat": return 7
        default: return 0
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Helper function to handle identical reminder names with better user feedback
    private func selectMostRecentForIdenticalNames(_ reminders: [EKReminder]) -> [EKReminder] {
        guard reminders.count > 1 else {
            return reminders
        }
        
        // Group reminders by title
        let groupedByTitle = Dictionary(grouping: reminders) { $0.title ?? "" }
        
        var result: [EKReminder] = []
        
        for (_, remindersWithSameTitle) in groupedByTitle {
            if remindersWithSameTitle.count == 1 {
                // Only one reminder with this title, add it
                result.append(contentsOf: remindersWithSameTitle)
            } else {
                // Multiple reminders with same title - provide detailed feedback
                // Found reminders with identical title
                
                
                // Sort by due date (soonest first) for more predictable behavior
                let sortedByDueDate = remindersWithSameTitle.sorted { reminder1, reminder2 in
                    let dueDate1 = reminder1.dueDateComponents?.date ?? Date.distantFuture
                    let dueDate2 = reminder2.dueDateComponents?.date ?? Date.distantFuture
                    return dueDate1 < dueDate2
                }
                
                if let selected = sortedByDueDate.first {
                    // TIP: Be more specific with times or dates to target exact reminders
                    result.append(selected)
                }
            }
        }
        
        return result
    }
    
    // Enhanced matching for time-specific reminders
    private func timeSpecificReminderMatching(searchText: String, reminders: [EKReminder]) -> [EKReminder] {
        let searchLower = searchText.lowercased()
        // Time-specific matching
        
        // Extract title and time information
        let (titlePart, timePart) = extractTitleAndTime(from: searchLower)
        // Extracted title and time
        
        // Safety check: if title extraction failed, use original search
        let finalTitlePart = titlePart.isEmpty ? searchLower : titlePart
        // Final title part determined
        
        // First, filter by title
        let titleMatches = reminders.filter { reminder in
            let reminderTitle = reminder.title?.lowercased() ?? ""
            return reminderTitle.contains(finalTitlePart)
        }
        
        // Found title matches
        
        
        // If we have time information, filter further by time
        if !timePart.isEmpty {
            let timeMatches = titleMatches.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { 
                    return false 
                }
                return doesTimeMatch(dueDate: dueDate, timeString: timePart)
            }
            
            // Found time-specific matches
            
            // Special handling for identical names - if multiple reminders have same name but different times
            if timeMatches.count > 1 {
                let uniqueTitles = Set(timeMatches.compactMap { $0.title })
                if uniqueTitles.count == 1 {
                    // Multiple reminders with identical name found with matching times
                    
                    // Multiple identical reminders match time criteria, selecting the first one found
                    // TIP: To be more specific, include more context like day or exact time in your command
                    
                    // Return the first match rather than trying to guess
                    if let selectedReminder = timeMatches.first {
                        return [selectedReminder]
                    }
                }
            }
            
            // If we found exact time matches, use those. Otherwise fall back to title matches
            if timeMatches.isEmpty {
                // No exact time matches found, falling back to title matches
                // For title-only matches with identical names, also select most recent
                return selectMostRecentForIdenticalNames(titleMatches)
            } else {
                // Using exact time matches
                return timeMatches
            }
        }
        
        // No time specified, return all title matches (but handle identical names)
        // No time specified, checking for identical names in title matches
        return selectMostRecentForIdenticalNames(titleMatches)
    }
    
    // Extract title and time parts from search text
    private func extractTitleAndTime(from searchText: String) -> (title: String, time: String) {
        let timePatterns = [
            "(at|from) \\d{1,2}:\\d{2}(am|pm|AM|PM)?",    // at 7:45pm, from 21:45
            "(at|from) \\d{1,2}(am|pm|AM|PM)",           // at 7pm, from 7AM
            "\\d{1,2}:\\d{2}(am|pm|AM|PM)?",             // 7:45pm, 21:45, 9:45 (standalone)
            "\\d{1,2}(am|pm|AM|PM)"                      // 7pm, 7AM (standalone)
        ]
        
        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: searchText, options: [], range: NSRange(searchText.startIndex..., in: searchText)) {
                
                let timeRange = Range(match.range, in: searchText)!
                let timeString = String(searchText[timeRange])
                let titleString = searchText.replacingOccurrences(of: timeString, with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                return (titleString, timeString)
            }
        }
        
        return (searchText, "")
    }
    
    // Check if a reminder's time matches the specified time string
    private func doesTimeMatch(dueDate: Date, timeString: String) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: dueDate)
        let minute = calendar.component(.minute, from: dueDate)
        
        
        // Parse the time string - handle both "at" and "from"
        let cleanTime = timeString.replacingOccurrences(of: "at ", with: "")
                                  .replacingOccurrences(of: "from ", with: "")
                                  .lowercased()
        
        // Handle formats like "7:45pm", "7pm", "7:45", "21:45"
        if cleanTime.contains(":") {
            let parts = cleanTime.components(separatedBy: ":")
            guard parts.count >= 2,
                  let searchHour = Int(parts[0]),
                  let searchMinuteStr = parts[1].components(separatedBy: CharacterSet.letters).first,
                  let searchMinute = Int(searchMinuteStr) else { 
                return false 
            }
            
            var adjustedSearchHour = searchHour
            
            // Handle AM/PM only if present (24-hour format doesn't need adjustment)
            if cleanTime.contains("pm") && searchHour != 12 {
                adjustedSearchHour += 12
            } else if cleanTime.contains("am") && searchHour == 12 {
                adjustedSearchHour = 0
            }
            // For ambiguous times like "9:34" (no AM/PM), use configurable default or check both possibilities
            
            // First try exact match
            if hour == adjustedSearchHour && minute == searchMinute {
                return true
            }
            
            // If no AM/PM specified and no exact match, use default AM/PM preference
            if !cleanTime.contains("am") && !cleanTime.contains("pm") {
                let defaultAmPm = colorTheme?.defaultAmPm ?? "AM"
                var preferredHour = searchHour
                
                if defaultAmPm == "PM" && searchHour != 12 {
                    preferredHour += 12
                } else if defaultAmPm == "AM" && searchHour == 12 {
                    preferredHour = 0
                }
                
                if hour == preferredHour && minute == searchMinute {
                    return true
                }
                
                // Also try the alternative if the preferred doesn't match
                let alternativeHour = searchHour < 12 ? searchHour + 12 : searchHour - 12
                if alternativeHour >= 0 && alternativeHour <= 23 && hour == alternativeHour && minute == searchMinute {
                    return true
                }
            }
            
            return false
        } else {
            // Handle formats like "7pm", "7am", or just "7" (no AM/PM)
            let numberStr = cleanTime.components(separatedBy: CharacterSet.letters).first ?? ""
            guard let searchHour = Int(numberStr) else { return false }
            
            var adjustedSearchHour = searchHour
            
            if cleanTime.contains("pm") && searchHour != 12 {
                adjustedSearchHour += 12
            } else if cleanTime.contains("am") && searchHour == 12 {
                adjustedSearchHour = 0
            } else if !cleanTime.contains("am") && !cleanTime.contains("pm") {
                // No AM/PM specified - use default preference
                let defaultAmPm = colorTheme?.defaultAmPm ?? "AM"
                if defaultAmPm == "PM" && searchHour != 12 {
                    adjustedSearchHour += 12
                } else if defaultAmPm == "AM" && searchHour == 12 {
                    adjustedSearchHour = 0
                }
            }
            
            return hour == adjustedSearchHour && minute == 0
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
    
    func updateReminderDate(_ reminder: EKReminder, newDate: Date, completion: @escaping (Bool, Error?) -> Void) {
        guard hasAccess else {
            completion(false, ReminderError.accessDenied)
            return
        }
        
        let dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: newDate)
        reminder.dueDateComponents = dueDateComponents
        
        do {
            try eventStore.save(reminder, commit: true)
            completion(true, nil)
        } catch {
            completion(false, error)
        }
    }
    
    func getAllReminders(completion: @escaping ([EKReminder]) -> Void) {
        guard hasAccess else {
            // No access to reminders
            completion([])
            return
        }
        
        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForReminders(in: calendars)
        
        // Fetching all reminders from calendars
        
        eventStore.fetchReminders(matching: predicate) { reminders in
            let allReminders = reminders ?? []
            // EventKit returned total reminders
            
            // Reminder details logged
            
            DispatchQueue.main.async {
                completion(allReminders)
            }
        }
    }
}

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