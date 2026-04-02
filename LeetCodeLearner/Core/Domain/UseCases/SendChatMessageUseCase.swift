import Foundation

final class SendChatMessageUseCase {
    private let openRouterService: OpenRouterServiceProtocol
    private let chatRepo: ChatRepositoryProtocol

    init(openRouterService: OpenRouterServiceProtocol, chatRepo: ChatRepositoryProtocol) {
        self.openRouterService = openRouterService
        self.chatRepo = chatRepo
    }

    func execute(
        sessionId: UUID,
        userMessage: String,
        problem: Problem,
        isUMPIREMode: Bool,
        model: String = "anthropic/claude-sonnet-4-20250514"
    ) -> AsyncThrowingStream<String, Error> {
        // Save user message and build history on MainActor (repo uses mainContext)
        let userMsg = ChatMessage(
            sessionId: sessionId,
            role: .user,
            content: userMessage
        )
        chatRepo.addMessage(userMsg, to: sessionId)

        // Build message history
        let history = chatRepo.getMessages(for: sessionId)
        let openRouterMessages = history.map { msg in
            OpenRouterMessage(role: msg.role.rawValue, content: msg.content)
        }

        // Select system prompt
        let systemPrompt = isUMPIREMode
            ? ChatSystemPrompts.umpireSolution(problem: problem)
            : ChatSystemPrompts.socraticTutor(problem: problem)

        // Stream from API
        let stream = openRouterService.streamMessage(
            messages: openRouterMessages,
            systemPrompt: systemPrompt,
            model: model,
            maxTokens: isUMPIREMode ? 8192 : 4096
        )

        // Wrap stream to accumulate and save final response
        let repo = self.chatRepo
        return AsyncThrowingStream { continuation in
            let task = Task {
                var fullResponse = ""
                do {
                    for try await chunk in stream {
                        try Task.checkCancellation()
                        fullResponse += chunk
                        continuation.yield(chunk)
                    }

                    // Save complete assistant message on MainActor
                    let assistantMsg = ChatMessage(
                        sessionId: sessionId,
                        role: .assistant,
                        content: fullResponse
                    )
                    await MainActor.run {
                        repo.addMessage(assistantMsg, to: sessionId)
                    }

                    continuation.finish()
                } catch {
                    // Save partial response if any
                    if !fullResponse.isEmpty {
                        let assistantMsg = ChatMessage(
                            sessionId: sessionId,
                            role: .assistant,
                            content: fullResponse
                        )
                        await MainActor.run {
                            repo.addMessage(assistantMsg, to: sessionId)
                        }
                    }
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
