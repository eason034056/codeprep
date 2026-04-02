import Foundation

// MARK: - Request Models

struct OpenRouterRequest: Encodable {
    let model: String
    let messages: [OpenRouterMessage]
    let stream: Bool
    let maxTokens: Int?
    let temperature: Double?

    enum CodingKeys: String, CodingKey {
        case model, messages, stream
        case maxTokens = "max_tokens"
        case temperature
    }
}

struct OpenRouterMessage: Codable {
    let role: String  // "system", "user", "assistant"
    let content: String
}

// MARK: - Non-streaming Response

struct OpenRouterResponse: Decodable {
    let id: String
    let choices: [OpenRouterChoice]
    let usage: OpenRouterUsage?
}

struct OpenRouterChoice: Decodable {
    let message: OpenRouterMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

struct OpenRouterUsage: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Streaming Response (SSE chunks)

struct OpenRouterStreamChunk: Decodable {
    let id: String?
    let choices: [OpenRouterStreamChoice]
}

struct OpenRouterStreamChoice: Decodable {
    let delta: OpenRouterDelta
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
    }
}

struct OpenRouterDelta: Decodable {
    let role: String?
    let content: String?
}

// MARK: - Error Response

struct OpenRouterErrorResponse: Decodable {
    let error: OpenRouterErrorDetail
}

struct OpenRouterErrorDetail: Decodable {
    let message: String
    let type: String?
    let code: Int?
}
