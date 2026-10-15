import Foundation

enum ClaudeError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case overloaded
    case server(status: Int, message: String)
    case refused
    case truncated
    case unreadableResponse
    case offline

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "No API key yet. Paste your Anthropic API key into Secrets.xcconfig, then rebuild the app."
        case .invalidAPIKey:
            "The API key was rejected. Check the key in Secrets.xcconfig."
        case .rateLimited:
            "Too many requests right now. Wait a minute and try again."
        case .overloaded:
            "The AI service is busy. Try again in a moment."
        case .server(let status, let message):
            "The AI service returned an error (\(status)): \(message)"
        case .refused:
            "The AI chef can't help with that request. Try asking for a different dish."
        case .truncated:
            "The answer was cut off. Try again, maybe with a simpler request."
        case .unreadableResponse:
            "The AI sent back something unexpected. Try again."
        case .offline:
            "You seem to be offline. Connect to the internet and try again."
        }
    }
}

/// Calls the Claude Messages API over HTTPS (there's no official Swift SDK).
/// Every call uses structured outputs, so replies always match the JSON Schema we send.
struct ClaudeClient: Sendable {
    enum Content: Sendable {
        case text(String)
        /// Base64-encoded JPEG.
        case jpeg(base64: String)

        var json: JSONValue {
            switch self {
            case .text(let text):
                ["type": "text", "text": .string(text)]
            case .jpeg(let data):
                ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": .string(data)]]
            }
        }
    }

    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let model = "claude-opus-5-5"

    let apiKey: String
    var transport: Transport = { try await URLSession.shared.data(for: $0) }

    /// Reads the key that Secrets.xcconfig puts into Info.plist.
    static func fromBundle(_ bundle: Bundle = .main) throws -> ClaudeClient {
        let key = (bundle.object(forInfoDictionaryKey: "AnthropicAPIKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.hasPrefix("$(") else { throw ClaudeError.missingAPIKey }
        return ClaudeClient(apiKey: key)
    }

    /// Lets Claude look things up on the web (used to ground recipes in real, well-regarded ones).
    static func webSearch(maxUses: Int) -> JSONValue {
        ["type": "web_search_20250305", "name": "web_search", "max_uses": .number(Double(maxUses))]
    }

    func request(system: String, content: [Content], schema: JSONValue, tools: [JSONValue] = []) throws -> URLRequest {
        try request(system: system, messages: [["role": "user", "content": .array(content.map(\.json))]],
                    schema: schema, tools: tools)
    }

    func request(system: String, messages: [JSONValue], schema: JSONValue, tools: [JSONValue]) throws -> URLRequest {
        var fields: [String: JSONValue] = [
            "model": .string(Self.model),
            "max_tokens": 16000,
            "system": .string(system),
            "messages": .array(messages),
            "output_config": [
                "effort": "medium",
                "format": ["type": "json_schema", "schema": schema],
            ],
            // If the model declines a request, the API retries on a fallback model in the same call.
            "fallbacks": "default",
        ]
        if !tools.isEmpty { fields["tools"] = .array(tools) }
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 240)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(JSONValue.object(fields))
        return request
    }

    /// Sends one message and decodes the JSON reply into `T`.
    func send<T: Decodable>(system: String, content: [Content], schema: JSONValue, tools: [JSONValue] = [],
                            as type: T.Type) async throws -> T {
        var messages: [JSONValue] = [["role": "user", "content": .array(content.map(\.json))]]
        // Web searches run on Anthropic's servers. A long search can pause the turn; sending the
        // conversation back unchanged lets it pick up where it left off.
        for _ in 0..<4 {
            let request = try request(system: system, messages: messages, schema: schema, tools: tools)
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await transport(request)
            } catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(error.code) {
                throw ClaudeError.offline
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200, let reply = try? JSONDecoder().decode(JSONValue.self, from: data),
               reply["stop_reason"] == .string("pause_turn"), let content = reply["content"] {
                messages.append(["role": "assistant", "content": content])
                continue
            }
            return try Self.decode(T.self, data: data, status: status)
        }
        throw ClaudeError.truncated
    }

    private struct MessageResponse: Decodable {
        struct Block: Decodable {
            let type: String
            let text: String?
        }
        let content: [Block]
        let stop_reason: String?
    }

    private struct ErrorResponse: Decodable {
        struct Detail: Decodable { let message: String }
        let error: Detail
    }

    static func decode<T: Decodable>(_ type: T.Type, data: Data, status: Int) throws -> T {
        guard status == 200 else {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error.message ?? "Unknown error"
            switch status {
            case 401, 403: throw ClaudeError.invalidAPIKey
            case 429: throw ClaudeError.rateLimited
            case 529, 503: throw ClaudeError.overloaded
            default: throw ClaudeError.server(status: status, message: message)
            }
        }
        guard let message = try? JSONDecoder().decode(MessageResponse.self, from: data) else {
            throw ClaudeError.unreadableResponse
        }
        switch message.stop_reason {
        case "refusal": throw ClaudeError.refused
        case "max_tokens": throw ClaudeError.truncated
        default: break
        }
        // With structured outputs the answer is the last text block (thinking and search blocks come first).
        guard let text = message.content.last(where: { $0.type == "text" })?.text,
              let json = text.data(using: .utf8),
              let value = try? JSONDecoder().decode(T.self, from: json) else {
            throw ClaudeError.unreadableResponse
        }
        return value
    }
}
