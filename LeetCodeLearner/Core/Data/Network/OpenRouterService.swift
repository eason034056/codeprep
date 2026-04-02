import Foundation

protocol OpenRouterServiceProtocol: Sendable {
    func sendMessage(
        messages: [OpenRouterMessage],
        systemPrompt: String,
        model: String,
        maxTokens: Int
    ) async throws -> String

    func streamMessage(
        messages: [OpenRouterMessage],
        systemPrompt: String,
        model: String,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error>
}

final class OpenRouterService: OpenRouterServiceProtocol, @unchecked Sendable {
    private let baseURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    private let session: URLSession
    private let apiKeyManager: APIKeyManager

    init(apiKeyManager: APIKeyManager = .shared, session: URLSession = .shared) {
        self.apiKeyManager = apiKeyManager
        self.session = session
    }

    // MARK: - Non-streaming

    func sendMessage(
        messages: [OpenRouterMessage],
        systemPrompt: String,
        model: String = "anthropic/claude-sonnet-4-20250514",
        maxTokens: Int = 4096
    ) async throws -> String {
        let allMessages = [OpenRouterMessage(role: "system", content: systemPrompt)] + messages
        let requestBody = OpenRouterRequest(
            model: model,
            messages: allMessages,
            stream: false,
            maxTokens: maxTokens,
            temperature: 0.7
        )

        let request = try buildRequest(body: requestBody)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoded = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw OpenRouterError.emptyResponse
        }
        return content
    }

    // MARK: - Streaming

    func streamMessage(
        messages: [OpenRouterMessage],
        systemPrompt: String,
        model: String = "anthropic/claude-sonnet-4-20250514",
        maxTokens: Int = 4096
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let allMessages = [OpenRouterMessage(role: "system", content: systemPrompt)] + messages
                    let requestBody = OpenRouterRequest(
                        model: model,
                        messages: allMessages,
                        stream: true,
                        maxTokens: maxTokens,
                        temperature: 0.7
                    )

                    let request = try self.buildRequest(body: requestBody)
                    let (bytes, response) = try await self.session.bytes(for: request)
                    try self.validateResponse(response)

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))

                        if jsonString.trimmingCharacters(in: .whitespaces) == "[DONE]" {
                            break
                        }

                        guard let jsonData = jsonString.data(using: .utf8) else { continue }

                        do {
                            let chunk = try JSONDecoder().decode(OpenRouterStreamChunk.self, from: jsonData)
                            if let content = chunk.choices.first?.delta.content {
                                continuation.yield(content)
                            }
                        } catch {
                            // Skip malformed chunks
                            continue
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Private Helpers

    private func buildRequest(body: OpenRouterRequest) throws -> URLRequest {
        let apiKey = try apiKeyManager.retrieve()

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("CodePrep/1.0", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("CodePrep", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 120

        return request
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw OpenRouterError.unauthorized
        case 429:
            throw OpenRouterError.rateLimited
        case 400...499:
            throw OpenRouterError.clientError(httpResponse.statusCode)
        case 500...599:
            throw OpenRouterError.serverError(httpResponse.statusCode)
        default:
            throw OpenRouterError.unexpectedStatus(httpResponse.statusCode)
        }
    }
}

enum OpenRouterError: LocalizedError {
    case emptyResponse
    case invalidResponse
    case unauthorized
    case rateLimited
    case clientError(Int)
    case serverError(Int)
    case unexpectedStatus(Int)
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .emptyResponse: return "Received empty response from API"
        case .invalidResponse: return "Invalid response from server"
        case .unauthorized: return "Invalid API key. Please check your OpenRouter API key in Settings."
        case .rateLimited: return "Rate limited. Please try again in a moment."
        case .clientError(let code): return "Client error (\(code))"
        case .serverError(let code): return "Server error (\(code)). Please try again."
        case .unexpectedStatus(let code): return "Unexpected status code: \(code)"
        case .noAPIKey: return "No API key configured. Please add your OpenRouter API key in Settings."
        }
    }
}
