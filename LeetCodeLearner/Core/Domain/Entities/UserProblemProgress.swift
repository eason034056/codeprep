import Foundation

struct UserProblemProgress: Identifiable, Sendable {
    let id: UUID
    let userId: String
    let problemId: Int
    var status: ProblemStatus
    var attemptCount: Int
    var lastAttemptDate: Date?
    var bestApproachConfirmed: Bool
    var umpireSolutionUnlocked: Bool
    var notes: String

    static func new(problemId: Int, userId: String) -> UserProblemProgress {
        UserProblemProgress(
            id: UUID(),
            userId: userId,
            problemId: problemId,
            status: .unseen,
            attemptCount: 0,
            lastAttemptDate: nil,
            bestApproachConfirmed: false,
            umpireSolutionUnlocked: false,
            notes: ""
        )
    }
}
