import Foundation
@testable import LeetCodeLearner

final class MockProgressRepository: ProgressRepositoryProtocol, @unchecked Sendable {

    // MARK: - Storage

    var progressEntries: [Int: UserProblemProgress] = [:]
    var cards: [SpacedRepetitionCard] = []
    var dailyChallenges: [String: DailyChallenge] = [:]  // keyed by date string
    var completionDates: [Date] = []
    var completedIds: Set<Int> = []

    // MARK: - Tracking

    var saveDailyChallengeCallCount = 0
    var updateProgressCallCount = 0
    var lastProgressUpdate: UserProblemProgress?
    var saveCardCallCount = 0
    var lastSavedCard: SpacedRepetitionCard?

    // MARK: - UserProblemProgress

    func getProgress(for problemId: Int) -> UserProblemProgress? {
        progressEntries[problemId]
    }

    func getAllProgress() -> [UserProblemProgress] {
        Array(progressEntries.values)
    }

    func saveProgress(_ progress: UserProblemProgress) {
        progressEntries[progress.problemId] = progress
    }

    func updateProgress(problemId: Int, update: (inout UserProblemProgress) -> Void) {
        updateProgressCallCount += 1
        if var progress = progressEntries[problemId] {
            update(&progress)
            progressEntries[problemId] = progress
            lastProgressUpdate = progress
        }
    }

    // MARK: - SpacedRepetitionCard

    func getCard(for problemId: Int) -> SpacedRepetitionCard? {
        cards.first { $0.problemId == problemId }
    }

    func getOrCreateCard(for problemId: Int) -> SpacedRepetitionCard {
        if let existing = getCard(for: problemId) {
            return existing
        }
        let card = SpacedRepetitionCard.new(problemId: problemId, userId: "")
        cards.append(card)
        return card
    }

    func getAllCards() -> [SpacedRepetitionCard] {
        cards
    }

    func getDueCards(before date: Date) -> [SpacedRepetitionCard] {
        cards.filter { $0.nextReviewDate < date }
    }

    func saveCard(_ card: SpacedRepetitionCard) {
        saveCardCallCount += 1
        lastSavedCard = card
        if let index = cards.firstIndex(where: { $0.problemId == card.problemId }) {
            cards[index] = card
        } else {
            cards.append(card)
        }
    }

    // MARK: - DailyChallenge

    func getDailyChallenge(for date: Date) -> DailyChallenge? {
        let key = dateKey(date)
        return dailyChallenges[key]
    }

    func saveDailyChallenge(_ challenge: DailyChallenge) {
        saveDailyChallengeCallCount += 1
        let key = dateKey(challenge.date)
        dailyChallenges[key] = challenge
    }

    func markProblemCompleted(challengeId: UUID, problemId: Int) {
        for (key, var challenge) in dailyChallenges {
            if challenge.id == challengeId {
                challenge.completedProblemIds.insert(problemId)
                dailyChallenges[key] = challenge
                break
            }
        }
    }

    // MARK: - Gamification

    func getCompletionDates() -> [Date] {
        completionDates
    }

    func getCompletedProblemIds() -> Set<Int> {
        completedIds
    }

    // MARK: - Private

    private func dateKey(_ date: Date) -> String {
        let start = Calendar.current.startOfDay(for: date)
        return "\(start.timeIntervalSince1970)"
    }
}
