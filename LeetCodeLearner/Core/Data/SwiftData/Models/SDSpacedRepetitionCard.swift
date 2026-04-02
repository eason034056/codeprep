import Foundation
import SwiftData

@Model
final class SDSpacedRepetitionCard {
    @Attribute(.unique) var cardId: UUID
    var userId: String = ""
    var problemId: Int
    var repetitionCount: Int
    var interval: Double
    var easinessFactor: Double
    var nextReviewDate: Date
    var lastReviewDate: Date?
    var lastQualityRating: Int?
    var lastModified: Date = Date()
    var syncStatus: String = "pendingUpload"

    init(cardId: UUID, userId: String = "", problemId: Int, repetitionCount: Int, interval: Double, easinessFactor: Double, nextReviewDate: Date, lastReviewDate: Date?, lastQualityRating: Int?) {
        self.cardId = cardId
        self.userId = userId
        self.problemId = problemId
        self.repetitionCount = repetitionCount
        self.interval = interval
        self.easinessFactor = easinessFactor
        self.nextReviewDate = nextReviewDate
        self.lastReviewDate = lastReviewDate
        self.lastQualityRating = lastQualityRating
    }
}
