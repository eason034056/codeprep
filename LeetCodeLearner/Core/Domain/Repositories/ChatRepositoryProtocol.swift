import Foundation

protocol ChatRepositoryProtocol: Sendable {
    func getSession(for problemId: Int) -> ChatSession?
    func getOrCreateSession(for problemId: Int) -> ChatSession
    func getAllSessions() -> [ChatSession]
    func addMessage(_ message: ChatMessage, to sessionId: UUID)
    func setUMPIREMode(sessionId: UUID, enabled: Bool)
    func getMessages(for sessionId: UUID) -> [ChatMessage]
    func deleteSession(_ sessionId: UUID)
}
