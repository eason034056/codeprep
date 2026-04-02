import Foundation

protocol ProgressRepositoryProtocol: Sendable {
    // UserProblemProgress
    func getProgress(for problemId: Int) -> UserProblemProgress?
    func getAllProgress() -> [UserProblemProgress]
    func saveProgress(_ progress: UserProblemProgress)
    func updateProgress(problemId: Int, update: (inout UserProblemProgress) -> Void)

    // SpacedRepetitionCard
    func getCard(for problemId: Int) -> SpacedRepetitionCard?
    func getOrCreateCard(for problemId: Int) -> SpacedRepetitionCard
    func getAllCards() -> [SpacedRepetitionCard]
    func getDueCards(before date: Date) -> [SpacedRepetitionCard]
    func saveCard(_ card: SpacedRepetitionCard)

    // DailyChallenge
    func getDailyChallenge(for date: Date) -> DailyChallenge?
    func saveDailyChallenge(_ challenge: DailyChallenge)
    func markProblemCompleted(challengeId: UUID, problemId: Int)

    // Gamification
    func getCompletionDates() -> [Date]
    func getCompletedProblemIds() -> Set<Int>
}
