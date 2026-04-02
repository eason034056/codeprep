import Foundation

final class UpdateSpacedRepetitionUseCase {
    private let progressRepo: ProgressRepositoryProtocol
    private let sm2: SM2Algorithm

    init(progressRepo: ProgressRepositoryProtocol, sm2: SM2Algorithm = SM2Algorithm()) {
        self.progressRepo = progressRepo
        self.sm2 = sm2
    }

    /// Update spaced repetition card after user rates their recall quality (0-5)
    func execute(problemId: Int, qualityRating: Int) {
        var card = progressRepo.getOrCreateCard(for: problemId)
        card = sm2.update(card: card, quality: qualityRating)
        progressRepo.saveCard(card)

        // Update progress status based on quality
        progressRepo.updateProgress(problemId: problemId) { progress in
            progress.attemptCount += 1
            progress.lastAttemptDate = Date()
            if qualityRating >= 4 {
                progress.status = .solvedIndependently
            } else if qualityRating >= 3 {
                progress.status = .solvedWithHelp
            } else {
                progress.status = .attempted
            }
        }
    }
}
