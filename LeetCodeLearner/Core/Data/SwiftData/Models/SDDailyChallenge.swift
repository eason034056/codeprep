import Foundation
import SwiftData

@Model
final class SDDailyChallenge {
    @Attribute(.unique) var challengeId: UUID
    var userId: String = ""
    var date: Date
    var problemIds: [Int]
    var completedProblemIds: [Int]
    var lastModified: Date = Date()
    var syncStatus: String = "pendingUpload"

    init(challengeId: UUID, userId: String = "", date: Date, problemIds: [Int], completedProblemIds: [Int] = []) {
        self.challengeId = challengeId
        self.userId = userId
        self.date = date
        self.problemIds = problemIds
        self.completedProblemIds = completedProblemIds
    }
}
