//
//  GoogleCalendarService.swift
//  QuickReminders
//
//  Google Calendar API service for recurring reminders
//

#if os(iOS)
import Foundation

class GoogleCalendarService {
    private let baseURL = "https://www.googleapis.com/calendar/v3"
    private let authManager = GoogleAuthManager.shared

    // Calendar ID for QuickReminders (we'll create a dedicated calendar)
    private var quickRemindersCalendarId: String?

    // MARK: - Calendar Management

    func getOrCreateQuickRemindersCalendar() async throws -> String {
        // Check if we already have the calendar ID cached
        if let calendarId = quickRemindersCalendarId {
            return calendarId
        }

        // Check UserDefaults
        if let savedId = UserDefaults.standard.string(forKey: "QuickRemindersGoogleCalendarID") {
            quickRemindersCalendarId = savedId
            return savedId
        }

        // Search for existing QuickReminders calendar
        let calendars = try await fetchCalendars()

        if let existing = calendars.first(where: { $0.summary == "QuickReminders" }) {
            quickRemindersCalendarId = existing.id
            UserDefaults.standard.set(existing.id, forKey: "QuickRemindersGoogleCalendarID")
            return existing.id
        }

        // Create new calendar
        let calendarId = try await createQuickRemindersCalendar()
        quickRemindersCalendarId = calendarId
        UserDefaults.standard.set(calendarId, forKey: "QuickRemindersGoogleCalendarID")
        return calendarId
    }

    private func fetchCalendars() async throws -> [GoogleCalendar] {
        let token = try await authManager.getAccessToken()

        var request = URLRequest(url: URL(string: "\(baseURL)/users/me/calendarList")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.apiError
        }

        guard httpResponse.statusCode == 200 else {
            // Log the error response
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Google Calendar List Fetch Error (status \(httpResponse.statusCode)): \(errorString)")
            }
            throw GoogleCalendarError.apiError
        }

        let result = try JSONDecoder().decode(CalendarListResponse.self, from: data)
        return result.items ?? []
    }

    // Public method to fetch all calendars
    func fetchAllCalendars() async throws -> [GoogleCalendar] {
        return try await fetchCalendars()
    }

    private func createQuickRemindersCalendar() async throws -> String {
        let token = try await authManager.getAccessToken()

        var request = URLRequest(url: URL(string: "\(baseURL)/calendars")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let calendarData: [String: Any] = [
            "summary": "QuickReminders",
            "description": "Reminders created with QuickReminders app",
            "timeZone": TimeZone.current.identifier
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: calendarData)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.apiError
        }

        guard httpResponse.statusCode == 200 else {
            // Log the error response
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Google Calendar Create Error (status \(httpResponse.statusCode)): \(errorString)")
            }
            throw GoogleCalendarError.createFailed
        }

        let calendar = try JSONDecoder().decode(GoogleCalendar.self, from: data)
        return calendar.id
    }

    // MARK: - Events (Recurring Reminders)

    func fetchEvents() async throws -> [(event: GoogleEvent, calendarId: String, calendarName: String)] {
        let token = try await authManager.getAccessToken()

        // Fetch ALL calendars
        let calendars = try await fetchAllCalendars()

        // Fetch events from now to 1 year in the future
        let now = Date()
        let oneYearLater = Calendar.current.date(byAdding: .year, value: 1, to: now)!

        let formatter = ISO8601DateFormatter()
        let timeMin = formatter.string(from: now)
        let timeMax = formatter.string(from: oneYearLater)

        var allEvents: [(event: GoogleEvent, calendarId: String, calendarName: String)] = []

        // Fetch events from ALL calendars
        for calendar in calendars {
            do {
                let urlString = "\(baseURL)/calendars/\(calendar.id)/events?timeMin=\(timeMin)&timeMax=\(timeMax)&singleEvents=false"
                guard let encodedURLString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let url = URL(string: encodedURLString) else {
                    continue
                }

                var request = URLRequest(url: url)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    continue
                }

                let result = try JSONDecoder().decode(EventsResponse.self, from: data)
                if let events = result.items {
                    // Track which calendar each event belongs to
                    for event in events {
                        allEvents.append((event: event, calendarId: calendar.id, calendarName: calendar.summary))
                    }
                }
            } catch {
                continue
            }
        }

        return allEvents
    }

    func createEvent(title: String, notes: String?, startDate: Date, recurrenceRule: String?, calendarId: String?) async throws -> GoogleEvent {
        let targetCalendarId: String
        if let calendarId = calendarId {
            targetCalendarId = calendarId
        } else {
            targetCalendarId = try await getOrCreateQuickRemindersCalendar()
        }

        let token = try await authManager.getAccessToken()

        var request = URLRequest(url: URL(string: "\(baseURL)/calendars/\(targetCalendarId)/events")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        // End date (30 minutes after start for events)
        let endDate = Calendar.current.date(byAdding: .minute, value: 30, to: startDate)!

        var eventData: [String: Any] = [
            "summary": title,
            "start": [
                "dateTime": formatter.string(from: startDate),
                "timeZone": TimeZone.current.identifier
            ],
            "end": [
                "dateTime": formatter.string(from: endDate),
                "timeZone": TimeZone.current.identifier
            ],
            "reminders": [
                "useDefault": false,
                "overrides": [
                    ["method": "popup", "minutes": 0]
                ]
            ]
        ]

        if let notes = notes, !notes.isEmpty {
            eventData["description"] = notes
        }

        if let recurrenceRule = recurrenceRule {
            eventData["recurrence"] = [recurrenceRule]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: eventData)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.apiError
        }

        guard httpResponse.statusCode == 200 else {
            // Log the error response
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Google Calendar API Error (status \(httpResponse.statusCode)): \(errorString)")
            }
            throw GoogleCalendarError.createFailed
        }

        return try JSONDecoder().decode(GoogleEvent.self, from: data)
    }

    func updateEvent(eventId: String, calendarId: String, newDate: Date) async throws {
        let token = try await authManager.getAccessToken()

        var request = URLRequest(url: URL(string: "\(baseURL)/calendars/\(calendarId)/events/\(eventId)")!)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let endDate = Calendar.current.date(byAdding: .minute, value: 30, to: newDate)!

        let eventData: [String: Any] = [
            "start": [
                "dateTime": formatter.string(from: newDate),
                "timeZone": TimeZone.current.identifier
            ],
            "end": [
                "dateTime": formatter.string(from: endDate),
                "timeZone": TimeZone.current.identifier
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: eventData)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GoogleCalendarError.updateFailed
        }
    }

    func deleteEvent(eventId: String, calendarId: String) async throws {
        let token = try await authManager.getAccessToken()

        var request = URLRequest(url: URL(string: "\(baseURL)/calendars/\(calendarId)/events/\(eventId)")!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 else {
            throw GoogleCalendarError.deleteFailed
        }
    }

    func renameEventAsCompleted(eventId: String, calendarId: String, currentTitle: String) async throws {
        let token = try await authManager.getAccessToken()

        var request = URLRequest(url: URL(string: "\(baseURL)/calendars/\(calendarId)/events/\(eventId)")!)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add " - COMPLETED" to the summary if not already there
        let newTitle = currentTitle.hasSuffix(" - COMPLETED") ? currentTitle : "\(currentTitle) - COMPLETED"

        let eventData: [String: Any] = [
            "summary": newTitle
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: eventData)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GoogleCalendarError.updateFailed
        }
    }
}

enum GoogleCalendarError: Error, LocalizedError {
    case invalidURL
    case apiError
    case createFailed
    case updateFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid calendar URL"
        case .apiError:
            return "Google Calendar API error"
        case .createFailed:
            return "Failed to create calendar event"
        case .updateFailed:
            return "Failed to update event"
        case .deleteFailed:
            return "Failed to delete event"
        }
    }
}
#endif
