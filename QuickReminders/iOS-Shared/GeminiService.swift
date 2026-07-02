//
//  GeminiService.swift
//  QuickReminders - iOS Shared
//
//  Singleton service for Gemini API calls to transform multilingual text
//

#if os(iOS)
import Foundation

struct AIVoiceLanguage {
    let locale: String
    let displayName: String
    let exampleTriggerWords: String

    static let all: [AIVoiceLanguage] = [
        AIVoiceLanguage(locale: "en-US", displayName: "English (US)",        exampleTriggerWords: "e.g. done, send"),
        AIVoiceLanguage(locale: "cs-CZ", displayName: "Czech",              exampleTriggerWords: "e.g. hotovo, odeslat"),
        AIVoiceLanguage(locale: "sk-SK", displayName: "Slovak",             exampleTriggerWords: "e.g. hotovo, odoslať"),
        AIVoiceLanguage(locale: "de-DE", displayName: "German",             exampleTriggerWords: "e.g. fertig, senden"),
        AIVoiceLanguage(locale: "fr-FR", displayName: "French",             exampleTriggerWords: "e.g. terminé, envoyer"),
        AIVoiceLanguage(locale: "es-ES", displayName: "Spanish",            exampleTriggerWords: "e.g. listo, enviar"),
        AIVoiceLanguage(locale: "it-IT", displayName: "Italian",            exampleTriggerWords: "e.g. fatto, invia"),
        AIVoiceLanguage(locale: "pt-BR", displayName: "Portuguese (BR)",    exampleTriggerWords: "e.g. pronto, enviar"),
        AIVoiceLanguage(locale: "pl-PL", displayName: "Polish",             exampleTriggerWords: "e.g. gotowe, wyślij"),
        AIVoiceLanguage(locale: "ja-JP", displayName: "Japanese",           exampleTriggerWords: "e.g. 完了, 送信"),
        AIVoiceLanguage(locale: "zh-CN", displayName: "Chinese (Simplified)", exampleTriggerWords: "e.g. 完成, 发送"),
        AIVoiceLanguage(locale: "ko-KR", displayName: "Korean",             exampleTriggerWords: "e.g. 완료, 전송"),
        AIVoiceLanguage(locale: "ru-RU", displayName: "Russian",            exampleTriggerWords: "e.g. готово, отправить"),
        AIVoiceLanguage(locale: "uk-UA", displayName: "Ukrainian",          exampleTriggerWords: "e.g. готово, надіслати"),
    ]

    static func placeholder(for locale: String) -> String {
        return all.first { $0.locale == locale }?.exampleTriggerWords ?? "e.g. done, send"
    }
}

enum GeminiError: Error, LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case rateLimited
    case emptyResponse
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid or missing Gemini API key"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimited:
            return "Gemini API rate limit exceeded. Please try again shortly."
        case .emptyResponse:
            return "Gemini returned an empty response"
        case .invalidResponse(let detail):
            return "Unexpected response from Gemini: \(detail)"
        }
    }
}

class GeminiService {
    static let shared = GeminiService()

    private let defaultModel = "gemini-2.5-flash"
    private let baseEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/"

    static let sharedSystemPrompt = """
You are a reminder app input parser. Your job is to understand the user's intent and output a structured command for the app's English parser.

CRITICAL RULES:
1. Output ONLY the result — no explanations, no quotes, no extra text whatsoever
2. PRESERVE the task title in the ORIGINAL language — do NOT translate or paraphrase it
3. Only translate command keywords and date/time/recurrence expressions into English keywords

OUTPUT FORMAT — choose based on intent:

A) CREATE reminder (default when no command detected):
   Format: "[original-language title] [date] [time] [recurrence]"
   - Strip leading preambles like "vytvoř", "přidej", "remind me to", "add", "erinnere mich", "添加", "set reminder", etc.
   - Date: "today" / "tomorrow" / "next Monday" / "in 3 days" / "January 15"
   - Time: "at 9am" / "at 3:30pm" / "at noon" / "at 12pm"
   - Recurrence: "every day" / "every week" / "every month" / "every Monday"
   - Examples:
     "vytvoř mi event vynést odpadky zítra v 9h" → "vynést odpadky tomorrow at 9am"
     "přidej schůzka s Petrem v pátek ve 14h" → "schůzka s Petrem next Friday at 2pm"
     "remind me gym every Monday at 7am" → "gym every Monday at 7am"
     "每周一早上9点买菜" → "买菜 every Monday at 9am"

B) DELETE reminder:
   Format: "delete [original-language title]"
   - Trigger words (any language): "delete", "remove", "rm", "odstraň", "odstran", "smazat", "smaž", "vymaž", "eliminar", "lösche", "supprimer", "elimina", "удали", etc.
   - Examples:
     "odstraň vynést odpadky" → "delete vynést odpadky"
     "smaž schůzku s Petrem" → "delete schůzku s Petrem"
     "remove buy groceries" → "delete buy groceries"

C) MOVE/RESCHEDULE reminder:
   Format: "move [original-language title] to [english date]"
   - Trigger words (any language): "move", "reschedule", "přesuň", "přesun", "posuň", "verschiebe", "déplacer", "mover", "переместить", etc.
   - Examples:
     "přesuň vynést odpadky na pátek" → "move vynést odpadky to next Friday"
     "move gym to tomorrow" → "move gym to tomorrow"

D) LIST reminders:
   Format: "list" or "list [english date]"
   - Trigger words (any language): "list", "show", "zobraz", "ukaž", "ukáž", "zeige", "afficher", "mostra", "показать", etc.
   - Examples:
     "zobraz připomínky na zítra" → "list tomorrow"
     "ukaž vše" → "list"
     "show today" → "list today"
"""

    private init() {}

    func transformText(_ input: String, apiKey: String, model: String = "") async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiError.invalidAPIKey
        }
        let resolvedModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultModel : model
        let urlString = "\(baseEndpoint)\(resolvedModel):generateContent?key=\(apiKey)"
        return try await makeRequest(input: input, urlString: urlString)
    }

    private func makeRequest(input: String, urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidAPIKey
        }

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "\(GeminiService.sharedSystemPrompt)\n\nInput: \(input)"]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 200
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.emptyResponse
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GeminiError.emptyResponse
        }
        return trimmed
    }
}
#endif
