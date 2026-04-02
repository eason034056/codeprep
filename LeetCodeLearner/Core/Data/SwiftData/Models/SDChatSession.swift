import Foundation
import SwiftData

@Model
final class SDChatSession {
    @Attribute(.unique) var sessionId: UUID
    var userId: String = ""
    var problemId: Int
    var createdAt: Date
    var isUMPIREMode: Bool
    @Relationship(deleteRule: .cascade, inverse: \SDChatMessage.session)
    var messages: [SDChatMessage]
    var lastModified: Date = Date()
    var syncStatus: String = "pendingUpload"

    init(sessionId: UUID, userId: String = "", problemId: Int, createdAt: Date, isUMPIREMode: Bool, messages: [SDChatMessage] = []) {
        self.sessionId = sessionId
        self.userId = userId
        self.problemId = problemId
        self.createdAt = createdAt
        self.isUMPIREMode = isUMPIREMode
        self.messages = messages
    }
}
