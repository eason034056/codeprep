import Foundation
import SwiftUI

@MainActor
final class ReviewQueueViewModel: ObservableObject {
    @Published var dueCards: [SpacedRepetitionCard] = []
    @Published var currentIndex: Int = 0
    @Published var isComplete: Bool = false

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
