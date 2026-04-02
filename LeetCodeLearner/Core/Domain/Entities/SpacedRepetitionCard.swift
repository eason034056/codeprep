import Foundation

struct SpacedRepetitionCard: Identifiable, Sendable {
    let id: UUID
    let userId: String
    let problemId: Int
    var repetitionCount: Int
    var interval: Double  // days
    var easinessFactor: Double  // starts 2.5, min 1.3
    var nextReviewDate: Date
    var lastReviewDate: Date?
    var lastQualityRating: Int?  // 0-5

    static func new(problemId: Int, userId: String) -> SpacedRepetitionCard {
        SpacedRepetitionCard(
            id: UUID(),
            userId: userId,
            problemId: problemId,
            repetitionCount: 0,
            interval: 0,
            easinessFactor: 2.5,
            nextReviewDate: Date(),
            lastReviewDate: nil,
            lastQualityRating: nil
        )
    }
}
