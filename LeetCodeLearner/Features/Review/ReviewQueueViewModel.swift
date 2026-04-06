import Foundation
import SwiftUI

@MainActor
final class ReviewQueueViewModel: ObservableObject {
    @Published var dueCards: [SpacedRepetitionCard] = []
    @Published var currentIndex: Int = 0
    @Published var isComplete: Bool = false

    // 💡 Weekly schedule — grouped by day, excluding today's already-due cards
    @Published var weeklyGroups: [(date: Date, cards: [(SpacedRepetitionCard, Problem)])] = []
    @Published var weeklyTotalCount: Int = 0

    private let progressRepo: ProgressRepositoryProtocol
    private let problemRepo: ProblemRepositoryProtocol
    private let updateSRUseCase: UpdateSpacedRepetitionUseCase

    init(
        progressRepo: ProgressRepositoryProtocol,
        problemRepo: ProblemRepositoryProtocol,
        updateSRUseCase: UpdateSpacedRepetitionUseCase
    ) {
        self.progressRepo = progressRepo
        self.problemRepo = problemRepo
        self.updateSRUseCase = updateSRUseCase
    }

    func loadDueCards() {
        dueCards = progressRepo.getDueCards(before: Date())
        currentIndex = 0
        isComplete = dueCards.isEmpty
        loadWeeklyCards()
    }

    // MARK: - Weekly Schedule

    /// Loads cards due this week (tomorrow through end-of-week), grouped by day.
    /// ⚠️ Excludes today's due cards to avoid duplication with the flashcard flow.
    func loadWeeklyCards() {
        let calendar = Calendar.current
        let now = Date()
        let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)

        // 💡 Calculate end of current week (Sunday 23:59:59)
        guard let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end else {
            weeklyGroups = []
            weeklyTotalCount = 0
            return
        }

        let futureCards = progressRepo.getDueCards(before: endOfWeek)
            .filter { $0.nextReviewDate >= startOfTomorrow }

        // Group cards by calendar day
        let grouped: [Date: [SpacedRepetitionCard]] = Dictionary(grouping: futureCards) { card in
            calendar.startOfDay(for: card.nextReviewDate)
        }

        // 💡 Map each group to (date, [(card, problem)]) — resolve problems eagerly
        var result: [(date: Date, cards: [(SpacedRepetitionCard, Problem)])] = []
        for (date, cards) in grouped.sorted(by: { $0.key < $1.key }) {
            let pairs: [(SpacedRepetitionCard, Problem)] = cards.compactMap { card in
                guard let problem = problemRepo.fetchById(card.problemId) else { return nil }
                return (card, problem)
            }
            guard !pairs.isEmpty else { continue }
            result.append((date: date, cards: pairs))
        }
        weeklyGroups = result

        weeklyTotalCount = weeklyGroups.reduce(0) { $0 + $1.cards.count }
    }

    var currentCard: SpacedRepetitionCard? {
        guard currentIndex < dueCards.count else { return nil }
        return dueCards[currentIndex]
    }

    func problemFor(card: SpacedRepetitionCard) -> Problem? {
        problemRepo.fetchById(card.problemId)
    }

    func rateCard(quality: Int) {
        guard let card = currentCard else { return }
        updateSRUseCase.execute(problemId: card.problemId, qualityRating: quality)

        if currentIndex + 1 < dueCards.count {
            currentIndex += 1
        } else {
            isComplete = true
        }
    }
}
