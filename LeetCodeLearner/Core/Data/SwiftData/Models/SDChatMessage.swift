import Foundation
import SwiftData

@Model
final class SDChatMessage {
    @Attribute(.unique) var messageId: UUID
    var sessionId: UUID
    var roleRaw: String
    var content: String
    var timestamp: Date
    var umpireStepRaw: Int?
    var session: SDChatSession?
    var lastModified: Date = Date()
    var syncStatus: String = "pendingUpload"

    init(messageId: UUID, sessionId: UUID, roleRaw: String, content: String, timestamp: Date, umpireStepRaw: Int?, session: SDChatSession? = nil) {
        self.messageId = messageId
        self.sessionId = sessionId
        self.roleRaw = roleRaw
        self.content = content
        self.timestamp = timestamp
        self.umpireStepRaw = umpireStepRaw
        self.session = session
    }
}
