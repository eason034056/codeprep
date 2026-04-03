import Foundation
@testable import LeetCodeLearner

// ⚠️ Must be @MainActor because ChatRepository is @MainActor and ChatViewModel
//    calls it on the main actor.
@MainActor
final class MockChatRepository: ChatRepositoryProtocol, @unchecked Sendable {

    // MARK: - Storage

    var sessions: [UUID: ChatSession] = [:]
    var messagesBySession: [UUID: [ChatMessage]] = [:]
    var umpireModeBySession: [UUID: Bool] = [:]

    // MARK: - Call Tracking

    var addMessageCallCount = 0
    var setUMPIREModeCallCount = 0
    var deleteSessionCallCount = 0

    // MARK: - Stub Helpers

    /// Pre-load a session so getOrCreateSession returns it
    func stub(session: ChatSession) {
        sessions[session.id] = session
        messagesBySession[session.id] = session.messages
    }

    // MARK: - ChatRepositoryProtocol

    func getSession(for problemId: Int) -> ChatSession? {
        sessions.values.first { $0.problemId == problemId }
    }

    func getOrCreateSession(for problemId: Int) -> ChatSession {
        if let existing = getSession(for: problemId) {
            return existing
        }
        let session = ChatSession(problemId: problemId)
        sessions[session.id] = session
        messagesBySession[session.id] = []
        return session
    }

    func getAllSessions() -> [ChatSession] {
        Array(sessions.values)
    }

    func addMessage(_ message: ChatMessage, to sessionId: UUID) {
        addMessageCallCount += 1
        messagesBySession[sessionId, default: []].append(message)
    }

    func setUMPIREMode(sessionId: UUID, enabled: Bool) {
        setUMPIREModeCallCount += 1
        umpireModeBySession[sessionId] = enabled
    }

    func getMessages(for sessionId: UUID) -> [ChatMessage] {
        messagesBySession[sessionId] ?? []
    }

    func deleteSession(_ sessionId: UUID) {
        deleteSessionCallCount += 1
        sessions.removeValue(forKey: sessionId)
        messagesBySession.removeValue(forKey: sessionId)
    }
}
