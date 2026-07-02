//
//  GroqService.swift
//  QuickReminders - iOS Shared
//
//  Groq API service for AI Mode text transformation
//

#if os(iOS)
import Foundation

class GroqService {
    static let shared = GroqService()

    private let endpoint = "https://api.groq.com/openai/v1/chat/completions"
    private let defaultModel = "llama-3.1-8b-instant"

    private init() {}

    func transformText(_ input: String, apiKey: String, model: String = "") async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiError.invalidAPIKey
        }

        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidAPIKey
        }

        let resolvedModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultModel : model
        let body: [String: Any] = [
            "model": resolvedModel,
            "messages": [
                ["role": "system", "content": GeminiService.sharedSystemPrompt],
                ["role": "user", "content": input]
            ],
            "temperature": 0.1,
            "max_tokens": 200
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GeminiError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200:
                break
            case 401, 403:
                throw GeminiError.invalidAPIKey
            case 429:
                throw GeminiError.rateLimited
            default:
                let detail = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                throw GeminiError.invalidResponse(detail)
            }
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw GeminiError.emptyResponse
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GeminiError.emptyResponse }
        return trimmed
    }
}
#endif
