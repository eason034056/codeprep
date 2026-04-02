import Foundation
import SwiftData

enum ModelContainerSetup {
    static func create() throws -> ModelContainer {
        let schema = Schema([
            SDProblem.self,
            SDSpacedRepetitionCard.self,
            SDUserProblemProgress.self,
            SDChatSession.self,
            SDChatMessage.self,
            SDDailyChallenge.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }

    /// Migrate records with empty userId to the given user.
    /// Called once per user on first sign-in to claim any pre-auth local data.
    static func migrateOrphanedData(context: ModelContext, toUserId userId: String) {
        let emptyId = ""

        let progressDescriptor = FetchDescriptor<SDUserProblemProgress>(
            predicate: #Predicate { $0.userId == emptyId }
        )
        if let orphaned = try? context.fetch(progressDescriptor) {
            for record in orphaned { record.userId = userId }
        }

        let cardDescriptor = FetchDescriptor<SDSpacedRepetitionCard>(
            predicate: #Predicate { $0.userId == emptyId }
        )
        if let orphaned = try? context.fetch(cardDescriptor) {
            for record in orphaned { record.userId = userId }
        }

        let sessionDescriptor = FetchDescriptor<SDChatSession>(
            predicate: #Predicate { $0.userId == emptyId }
        )
        if let orphaned = try? context.fetch(sessionDescriptor) {
            for record in orphaned { record.userId = userId }
        }

        let challengeDescriptor = FetchDescriptor<SDDailyChallenge>(
            predicate: #Predicate { $0.userId == emptyId }
        )
        if let orphaned = try? context.fetch(challengeDescriptor) {
            for record in orphaned { record.userId = userId }
        }

        try? context.save()
    }

    static func createInMemory() throws -> ModelContainer {
        let schema = Schema([
            SDProblem.self,
            SDSpacedRepetitionCard.self,
            SDUserProblemProgress.self,
            SDChatSession.self,
            SDChatMessage.self,
            SDDailyChallenge.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}
