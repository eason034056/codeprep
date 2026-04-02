import Foundation

struct ChatSession: Identifiable, Sendable {
    let id: UUID
    let userId: String
    let problemId: Int
    var messages: [ChatMessage]
    let createdAt: Date
    var isUMPIREMode: Bool

    init(id: UUID = UUID(), userId: String = "", problemId: Int, messages: [ChatMessage] = [], createdAt: Date = Date(), isUMPIREMode: Bool = false) {
        self.id = id
        self.userId = userId
        self.problemId = problemId
        self.messages = messages
        self.createdAt = createdAt
        self.isUMPIREMode = isUMPIREMode
    }
}
