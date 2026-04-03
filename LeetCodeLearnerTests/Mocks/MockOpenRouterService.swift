import Foundation
@testable import LeetCodeLearner

final class MockOpenRouterService: OpenRouterServiceProtocol, @unchecked Sendable {

    // MARK: - Configuration

    /// Chunks to yield from streamMessage, one by one
    var streamChunks: [String] = ["Hello", " world"]

    /// Delay between chunks (seconds) — simulates network latency
    var chunkDelay: TimeInterval = 0

    /// If set, streamMessage throws this error after yielding `errorAfterChunkIndex` chunks
    var streamError: Error?
    var errorAfterChunkIndex: Int = 0

    /// Full response for non-streaming sendMessage
    var sendMessageResponse: String = "Mock response"
    var sendMessageError: Error?

    // MARK: - Call Tracking

    var streamMessageCallCount = 0
    var sendMessageCallCount = 0

    // MARK: - OpenRouterServiceProtocol

    func sendMessage(
        messages: [OpenRouterMessage],
        systemPrompt: String,
        model: String,
        maxTokens: Int
    ) async throws -> String {
        sendMessageCallCount += 1
        if let error = sendMessageError { throw error }
        return sendMessageResponse
    }

    func streamMessage(
        messages: [OpenRouterMessage],
        systemPrompt: String,
        model: String,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        streamMessageCallCount += 1
        let chunks = streamChunks
        let delay = chunkDelay
        let error = streamError
        let errorIndex = errorAfterChunkIndex

        return AsyncThrowingStream { continuation in
            Task {
                for (index, chunk) in chunks.enumerated() {
                    if let error, index >= errorIndex {
                        continuation.finish(throwing: error)
                        return
                    }
                    if delay > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }
}
