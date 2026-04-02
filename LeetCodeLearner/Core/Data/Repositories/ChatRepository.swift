import Foundation
import SwiftData

@MainActor
final class ChatRepository: @preconcurrency ChatRepositoryProtocol, @unchecked Sendable {
    private let modelContext: ModelContext
    private let userId: String

    init(modelContext: ModelContext, userId: String) {
        self.modelContext = modelContext
        self.userId = userId
    }

    func getSession(for problemId: Int) -> ChatSession? {
        let uid = userId
        let descriptor = FetchDescriptor<SDChatSession>(
            predicate: #Predicate { $0.problemId == problemId && $0.userId == uid },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            guard let sd = try modelContext.fetch(descriptor).first else { return nil }
            return ChatMapper.sessionToDomain(sd)
        } catch {
            print("[ChatRepository] Failed to fetch session for problem \(problemId): \(error)")
            return nil
        }
    }

    func getOrCreateSession(for problemId: Int) -> ChatSession {
        if let existing = getSession(for: problemId) {
            return existing
        }
        let session = ChatSession(userId: userId, problemId: problemId)
        let sd = SDChatSession(
            sessionId: session.id,
            userId: userId,
            problemId: session.problemId,
            createdAt: session.createdAt,
            isUMPIREMode: session.isUMPIREMode
        )
        sd.lastModified = Date()
        sd.syncStatus = "pendingUpload"
        modelContext.insert(sd)
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .localDataDidChange, object: nil)
        } catch {
            print("[ChatRepository] Failed to save new session for problem \(problemId): \(error)")
        }
        return session
    }

    func getAllSessions() -> [ChatSession] {
        let uid = userId
        let descriptor = FetchDescriptor<SDChatSession>(
            predicate: #Predicate { $0.userId == uid },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            let results = try modelContext.fetch(descriptor)
            return results.map { ChatMapper.sessionToDomain($0) }
        } catch {
            print("[ChatRepository] Failed to fetch all sessions: \(error)")
            return []
        }
    }

    func addMessage(_ message: ChatMessage, to sessionId: UUID) {
        let descriptor = FetchDescriptor<SDChatSession>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )
        do {
            guard let session = try modelContext.fetch(descriptor).first else {
                print("[ChatRepository] Session not found for id \(sessionId)")
                return
            }
            let sdMessage = ChatMapper.messageToSwiftData(message, session: session)
            sdMessage.lastModified = Date()
            sdMessage.syncStatus = "pendingUpload"
            session.lastModified = Date()
            session.syncStatus = "pendingUpload"
            modelContext.insert(sdMessage)
            try modelContext.save()
            NotificationCenter.default.post(name: .localDataDidChange, object: nil)
        } catch {
            print("[ChatRepository] Failed to add message to session \(sessionId): \(error)")
        }
    }

    func setUMPIREMode(sessionId: UUID, enabled: Bool) {
        let descriptor = FetchDescriptor<SDChatSession>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )
        do {
            guard let session = try modelContext.fetch(descriptor).first else { return }
            session.isUMPIREMode = enabled
            session.lastModified = Date()
            session.syncStatus = "pendingUpload"
            try modelContext.save()
            NotificationCenter.default.post(name: .localDataDidChange, object: nil)
        } catch {
            print("[ChatRepository] Failed to set UMPIRE mode for session \(sessionId): \(error)")
        }
    }

    func getMessages(for sessionId: UUID) -> [ChatMessage] {
        let descriptor = FetchDescriptor<SDChatMessage>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        do {
            let results = try modelContext.fetch(descriptor)
            return results.map { ChatMapper.messageToDomain($0) }
        } catch {
            print("[ChatRepository] Failed to fetch messages for session \(sessionId): \(error)")
            return []
        }
    }

    func deleteSession(_ sessionId: UUID) {
        let descriptor = FetchDescriptor<SDChatSession>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )
        do {
            guard let session = try modelContext.fetch(descriptor).first else { return }
            modelContext.delete(session)
            try modelContext.save()
            NotificationCenter.default.post(name: .localDataDidChange, object: nil)
        } catch {
            print("[ChatRepository] Failed to delete session \(sessionId): \(error)")
        }
    }
}
