//
//  CustomAPIService.swift
//  QuickReminders - iOS Shared
//
//  Custom OpenAI-compatible API service (Ollama, LM Studio, self-hosted, etc.)
//

#if os(iOS)
import Foundation

class CustomAPIService {
    static let shared = CustomAPIService()
    private init() {}

    func transformText(_ input: String, baseURL: String, model: String, apiKey: String) async throws -> String {
        let cleanBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !cleanBase.isEmpty else { throw GeminiError.invalidAPIKey }

        let urlString = "\(cleanBase)/v1/chat/completions"
        guard let url = URL(string: urlString) else { throw GeminiError.invalidAPIKey }

        let body: [String: Any] = [
            "model": model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "llama3.1:8b" : model,
            "messages": [
                ["role": "system", "content": GeminiService.sharedSystemPrompt],
                ["role": "user", "content": input]
            ],
            "temperature": 0.1,
            "max_tokens": 200,
            "stream": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Send as both Cloudflare WAF token and Ollama Bearer auth
            request.setValue(apiKey, forHTTPHeaderField: "x-api-token")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
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

        // OpenAI-compatible response format
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
