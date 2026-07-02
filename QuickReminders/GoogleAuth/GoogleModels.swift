//
//  GoogleModels.swift
//  QuickReminders
//
//  Data models for Google Tasks and Google Calendar
//

#if os(iOS) || os(watchOS)
import Foundation

// MARK: - Google Tasks Models

struct GoogleTaskList: Codable {
    let id: String
    let title: String
    let updated: String?
}

struct TaskListsResponse: Codable {
    let items: [GoogleTaskList]?
}

struct GoogleTask: Codable {
    let id: String
    let title: String
    let notes: String?
    let due: String? // RFC 3339 timestamp (YYYY-MM-DD)
    let status: String // "needsAction" or "completed"
    let updated: String
    let completed: String?
}

struct TasksResponse: Codable {
    let items: [GoogleTask]?
}

// MARK: - Google Calendar Models

struct GoogleCalendar: Codable {
    let id: String
    let summary: String
    let description: String?
    let timeZone: String?
}

struct CalendarListResponse: Codable {
    let items: [GoogleCalendar]?
}

struct GoogleEvent: Codable {
    let id: String
    let summary: String?  // Some events don't have summary (e.g., all-day events, birthdays)
    let description: String?
    let start: EventDateTime
    let end: EventDateTime
    let recurrence: [String]? // RRULE for recurring events
    let status: String?
}

struct EventDateTime: Codable {
    let dateTime: String? // RFC 3339 timestamp
    let date: String? // Date only (YYYY-MM-DD)
    let timeZone: String?
}

struct EventsResponse: Codable {
    let items: [GoogleEvent]?
}

// MARK: - Helper Extensions

extension GoogleTask {
    var isCompleted: Bool {
        return status == "completed"
    }

    var dueDate: Date? {
        guard let due = due else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: due)
    }
}

extension GoogleEvent {
    var startDate: Date? {
        if let dateTime = start.dateTime {
            return ISO8601DateFormatter().date(from: dateTime)
        } else if let date = start.date {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            return formatter.date(from: date)
        }
        return nil
    }

    var isRecurring: Bool {
        return recurrence != nil && !(recurrence?.isEmpty ?? true)
    }
}
#endif
