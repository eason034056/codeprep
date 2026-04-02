import Foundation

struct ChatMessage: Identifiable, Sendable {
    let id: UUID
    let sessionId: UUID
    let role: ChatRole
    let content: String
    let timestamp: Date
    let umpireStep: UMPIREStep?

    init(id: UUID = UUID(), sessionId: UUID, role: ChatRole, content: String, timestamp: Date = Date(), umpireStep: UMPIREStep? = nil) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.umpireStep = umpireStep
    }
}
