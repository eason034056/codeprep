import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var streamingText: String = ""
    @Published var isStreaming: Bool = false
    @Published var isUMPIREMode: Bool = false
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?
    @Published var inputText: String = ""
    @Published var suggestedPrompts: [String] = [
        "Walk me through the approach",
        "What pattern fits this problem?",
        "Give me a hint to start",
        "Explain the brute force first"
    ]

    let problem: Problem
    private var session: ChatSession?
    private let sendChatUseCase: SendChatMessageUseCase
    private let evaluateUseCase: EvaluateUserApproachUseCase
    private let chatRepo: ChatRepositoryProtocol
    private let model: String
    private var currentTask: Task<Void, Never>?

    init(
        problem: Problem,
        sendChatUseCase: SendChatMessageUseCase,
        evaluateUseCase: EvaluateUserApproachUseCase,
        chatRepo: ChatRepositoryProtocol,
        model: String = "anthropic/claude-sonnet-4-20250514"
    ) {
        self.problem = problem
        self.sendChatUseCase = sendChatUseCase
        self.evaluateUseCase = evaluateUseCase
        self.chatRepo = chatRepo
        self.model = model
    }

    deinit {
        currentTask?.cancel()
    }

    /// Load session asynchronously to avoid blocking the main thread during navigation
    func loadSession() {
        let loaded = chatRepo.getOrCreateSession(for: problem.id)
        self.session = loaded
        self.messages = loaded.messages
        self.isUMPIREMode = loaded.isUMPIREMode
        self.isLoading = false
        updateSuggestedPrompts()
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming, let session else { return }

        inputText = ""
        isStreaming = true
        streamingText = ""
        errorMessage = nil
        HapticManager.shared.medium()

        // Add user message to display immediately
        let userMessage = ChatMessage(
            sessionId: session.id,
            role: .user,
            content: text
        )
        messages.append(userMessage)

        // Cancel any previous streaming task
        currentTask?.cancel()

        currentTask = Task {
            do {
                let stream = sendChatUseCase.execute(
                    sessionId: session.id,
                    userMessage: text,
                    problem: problem,
                    isUMPIREMode: isUMPIREMode,
                    model: model
                )

                var fullResponse = ""
                for try await chunk in stream {
                    try Task.checkCancellation()
                    fullResponse += chunk
                    streamingText = fullResponse
                }

                try Task.checkCancellation()

                // Clear streaming text before adding final message to avoid duplicate display
                streamingText = ""

                // Check for approach confirmation
                if evaluateUseCase.checkForConfirmation(in: fullResponse) {
                    let cleanedResponse = evaluateUseCase.cleanResponse(fullResponse)
                    evaluateUseCase.markApproachConfirmed(sessionId: session.id, problemId: problem.id)
                    isUMPIREMode = true

                    // Add cleaned response as message
                    let assistantMsg = ChatMessage(
                        sessionId: session.id,
                        role: .assistant,
                        content: cleanedResponse
                    )
                    messages.append(assistantMsg)

                    // Auto-trigger UMPIRE walkthrough
                    await requestUMPIRESolution()
                } else {
                    let assistantMsg = ChatMessage(
                        sessionId: session.id,
                        role: .assistant,
                        content: fullResponse
                    )
                    messages.append(assistantMsg)
                }

                isStreaming = false
                updateSuggestedPrompts()

            } catch is CancellationError {
                // Task was cancelled (user navigated away) — clean up silently
                streamingText = ""
                isStreaming = false
            } catch {
                errorMessage = error.localizedDescription
                streamingText = ""
                isStreaming = false
            }
        }
    }

    func selectSuggestedPrompt(_ prompt: String) {
        inputText = prompt
        sendMessage()
    }

    private func updateSuggestedPrompts() {
        if messages.isEmpty {
            suggestedPrompts = [
                "Walk me through the approach",
                "What pattern fits this problem?",
                "Give me a hint to start",
                "Explain the brute force first"
            ]
        } else if isUMPIREMode {
            suggestedPrompts = [
                "Explain the time complexity",
                "Are there alternative approaches?",
                "What are the edge cases?",
                "Can you optimize this further?"
            ]
        } else {
            suggestedPrompts = [
                "Is my approach correct?",
                "What data structure should I use?",
                "Help me think about edge cases",
                "What's the optimal complexity?"
            ]
        }
    }

    private func requestUMPIRESolution() async {
        guard let session else { return }

        isStreaming = true
        streamingText = ""

        do {
            let stream = sendChatUseCase.execute(
                sessionId: session.id,
                userMessage: "Please provide the complete UMPIRE method walkthrough for this problem based on my approach.",
                problem: problem,
                isUMPIREMode: true,
                model: model
            )

            var fullResponse = ""
            for try await chunk in stream {
                try Task.checkCancellation()
                fullResponse += chunk
                streamingText = fullResponse
            }

            try Task.checkCancellation()

            evaluateUseCase.markUMPIRESolutionDelivered(problemId: problem.id)

            // Clear streaming text BEFORE appending to avoid duplicate display
            streamingText = ""

            let assistantMsg = ChatMessage(
                sessionId: session.id,
                role: .assistant,
                content: fullResponse,
                umpireStep: .understand  // marks this as the UMPIRE response
            )
            messages.append(assistantMsg)
            isStreaming = false
        } catch is CancellationError {
            streamingText = ""
            isStreaming = false
        } catch {
            errorMessage = error.localizedDescription
            streamingText = ""
            isStreaming = false
        }
    }
}
