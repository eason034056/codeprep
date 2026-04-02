import Foundation

enum ChatMapper {
    static func sessionToDomain(_ sd: SDChatSession) -> ChatSession {
        let messages = sd.messages
            .sorted { $0.timestamp < $1.timestamp }
            .map { messageToDomain($0) }
        return ChatSession(
            id: sd.sessionId,
            userId: sd.userId,
            problemId: sd.problemId,
            messages: messages,
            createdAt: sd.createdAt,
            isUMPIREMode: sd.isUMPIREMode
        )
    }

    static func messageToDomain(_ sd: SDChatMessage) -> ChatMessage {
        let role = ChatRole(rawValue: sd.roleRaw) ?? .user
        let step = sd.umpireStepRaw.flatMap { UMPIREStep(rawValue: $0) }
        return ChatMessage(
            id: sd.messageId,
            sessionId: sd.sessionId,
            role: role,
            content: sd.content,
            timestamp: sd.timestamp,
            umpireStep: step
        )
    }

    static func messageToSwiftData(_ message: ChatMessage, session: SDChatSession? = nil) -> SDChatMessage {
        SDChatMessage(
            messageId: message.id,
            sessionId: message.sessionId,
            roleRaw: message.role.rawValue,
            content: message.content,
            timestamp: message.timestamp,
            umpireStepRaw: message.umpireStep?.rawValue,
            session: session
        )
    }
}
