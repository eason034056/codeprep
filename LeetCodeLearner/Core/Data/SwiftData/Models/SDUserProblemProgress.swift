import Foundation
import SwiftData

@Model
final class SDUserProblemProgress {
    @Attribute(.unique) var progressId: UUID
    var userId: String = ""
    var problemId: Int
    var statusRaw: String
    var attemptCount: Int
    var lastAttemptDate: Date?
    var bestApproachConfirmed: Bool
    var umpireSolutionUnlocked: Bool
    var notes: String
    var lastModified: Date = Date()
    var syncStatus: String = "pendingUpload"

    init(progressId: UUID, userId: String = "", problemId: Int, statusRaw: String, attemptCount: Int, lastAttemptDate: Date?, bestApproachConfirmed: Bool, umpireSolutionUnlocked: Bool, notes: String) {
        self.progressId = progressId
        self.userId = userId
        self.problemId = problemId
        self.statusRaw = statusRaw
        self.attemptCount = attemptCount
        self.lastAttemptDate = lastAttemptDate
        self.bestApproachConfirmed = bestApproachConfirmed
        self.umpireSolutionUnlocked = umpireSolutionUnlocked
        self.notes = notes
    }
}
