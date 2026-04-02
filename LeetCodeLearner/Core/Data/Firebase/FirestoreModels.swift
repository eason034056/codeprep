import Foundation

// MARK: - Firestore Document Models

struct FirestoreProgress: Codable {
    let progressId: String
    let problemId: Int
    let statusRaw: String
    let attemptCount: Int
    let lastAttemptDate: Date?
    let bestApproachConfirmed: Bool
    let umpireSolutionUnlocked: Bool
    let notes: String
    let lastModified: Date
}

struct FirestoreCard: Codable {
    let cardId: String
    let problemId: Int
    let repetitionCount: Int
    let interval: Double
    let easinessFactor: Double
    let nextReviewDate: Date
    let lastReviewDate: Date?
    let lastQualityRating: Int?
    let lastModified: Date
}

struct FirestoreDailyChallenge: Codable {
    let challengeId: String
    let date: Date
    let problemIds: [Int]
    let completedProblemIds: [Int]
    let lastModified: Date
}

struct FirestoreChatSession: Codable {
    let sessionId: String
    let problemId: Int
    let createdAt: Date
    let isUMPIREMode: Bool
    let lastModified: Date
}

struct FirestoreChatMessage: Codable {
    let messageId: String
    let sessionId: String
    let roleRaw: String
    let content: String
    let timestamp: Date
    let umpireStepRaw: Int?
    let lastModified: Date
}
