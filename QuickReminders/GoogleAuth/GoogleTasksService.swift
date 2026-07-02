//
//  GoogleTasksService.swift
//  QuickReminders
//
//  Google Tasks API service
//

#if os(iOS)
import Foundation

class GoogleTasksService {
    private let baseURL = "https://tasks.googleapis.com/tasks/v1"
    private let authManager = GoogleAuthManager.shared

    // MARK: - Task Lists

    func fetchTaskLists() async throws -> [GoogleTaskList] {
        let token = try await authManager.getAccessToken()

        var request = URLRequest(url: URL(string: "\(baseURL)/users/@me/lists")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleTasksError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Log the error response
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Google Tasks List Fetch Error (status \(httpResponse.statusCode)): \(errorString)")
            }
            throw GoogleTasksError.apiError(statusCode: httpResponse.statusCode)
        }

        let result = try JSONDecoder().decode(TaskListsResponse.self, from: data)
        return result.items ?? []
    }

    // MARK: - Tasks

    func fetchTasks(from listId: String) async throws -> [GoogleTask] {
        let token = try await authManager.getAccessToken()

        var request = URLRequest(url: URL(string: "\(baseURL)/lists/\(listId)/tasks?showCompleted=true")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleTasksError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GoogleTasksError.apiError(statusCode: httpResponse.statusCode)
        }

        let result = try JSONDecoder().decode(TasksResponse.self, from: data)
        return result.items ?? []
    }

    func createTask(title: String, notes: String?, dueDate: Date?, in listId: String) async throws -> GoogleTask {
        let token = try await authManager.getAccessToken()

        var request = URLRequest(url: URL(string: "\(baseURL)/lists/\(listId)/tasks")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var taskData: [String: Any] = ["title": title]

        if let notes = notes, !notes.isEmpty {
            taskData["notes"] = notes
        }

        if let dueDate = dueDate {
            // Google Tasks expects RFC 3339 timestamp (2024-12-11T00:00:00.000Z)
            // Even though Tasks only stores dates, the API requires full datetime format
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            taskData["due"] = formatter.string(from: dueDate)
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: taskData)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleTasksError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Log the error response
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Google Tasks API Error (status \(httpResponse.statusCode)): \(errorString)")
            }
            throw GoogleTasksError.apiError(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(GoogleTask.self, from: data)
    }

    func updateTask(taskId: String, in listId: String, newDate: Date) async throws {
        let token = try await authManager.getAccessToken()

        var request = URLRequest(url: URL(string: "\(baseURL)/lists/\(listId)/tasks/\(taskId)")!)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let taskData: [String: Any] = ["due": formatter.string(from: newDate)]

        request.httpBody = try JSONSerialization.data(withJSONObject: taskData)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleTasksError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GoogleTasksError.updateFailed
        }
    }

    func deleteTask(taskId: String, from listId: String) async throws {
        let token = try await authManager.getAccessToken()

        var request = URLRequest(url: URL(string: "\(baseURL)/lists/\(listId)/tasks/\(taskId)")!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleTasksError.invalidResponse
        }

        guard httpResponse.statusCode == 204 else {
            throw GoogleTasksError.deleteFailed
        }
    }

    func completeTask(taskId: String, in listId: String) async throws {
        let token = try await authManager.getAccessToken()

        var request = URLRequest(url: URL(string: "\(baseURL)/lists/\(listId)/tasks/\(taskId)")!)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let taskData: [String: Any] = ["status": "completed"]
        request.httpBody = try JSONSerialization.data(withJSONObject: taskData)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleTasksError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GoogleTasksError.updateFailed
        }
    }
}

enum GoogleTasksError: Error, LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int)
    case createFailed
    case updateFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Google Tasks"
        case .apiError(let code):
            return "Google Tasks API error (status: \(code))"
        case .createFailed:
            return "Failed to create task"
        case .updateFailed:
            return "Failed to update task"
        case .deleteFailed:
            return "Failed to delete task"
        }
    }
}
#endif
