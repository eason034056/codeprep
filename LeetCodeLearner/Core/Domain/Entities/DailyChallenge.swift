import Foundation

struct DailyChallenge: Identifiable, Sendable {
    let id: UUID
    let userId: String
    let date: Date
    let problemIds: [Int]  // exactly 3
    var completedProblemIds: Set<Int>

    init(id: UUID = UUID(), userId: String = "", date: Date = Date(), problemIds: [Int], completedProblemIds: Set<Int> = []) {
        self.id = id
        self.userId = userId
        self.date = date
        self.problemIds = problemIds
        self.completedProblemIds = completedProblemIds
    }

    var isFullyCompleted: Bool {
        completedProblemIds.count >= problemIds.count
    }

    var remainingCount: Int {
        problemIds.count - completedProblemIds.count
    }
}
