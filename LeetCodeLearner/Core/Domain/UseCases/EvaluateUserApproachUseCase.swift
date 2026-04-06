import Foundation

final class EvaluateUserApproachUseCase {
    private let chatRepo: ChatRepositoryProtocol
    private let progressRepo: ProgressRepositoryProtocol
    private let sm2: SM2Algorithm  // 💡 Injected to create SR cards after UMPIRE completion

    static let approachConfirmedMarker = "===APPROACH_CONFIRMED==="

    init(chatRepo: ChatRepositoryProtocol, progressRepo: ProgressRepositoryProtocol, sm2: SM2Algorithm = SM2Algorithm()) {
        self.chatRepo = chatRepo
        self.progressRepo = progressRepo
        self.sm2 = sm2
    }

    /// Check if the response contains the approach confirmed marker
    func checkForConfirmation(in response: String) -> Bool {
        response.contains(Self.approachConfirmedMarker)
    }

    /// Strip the marker from displayed text
    func cleanResponse(_ response: String) -> String {
        response.replacingOccurrences(of: Self.approachConfirmedMarker, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Mark the approach as confirmed and switch to UMPIRE mode
    func markApproachConfirmed(sessionId: UUID, problemId: Int) {
        chatRepo.setUMPIREMode(sessionId: sessionId, enabled: true)
        progressRepo.updateProgress(problemId: problemId) { progress in
            progress.bestApproachConfirmed = true
        }
    }

    /// Mark that the full UMPIRE solution was delivered
    func markUMPIRESolutionDelivered(problemId: Int) {
        progressRepo.updateProgress(problemId: problemId) { progress in
            progress.lastAttemptDate = Date()  // Fix: record solve date for streak counting
            progress.umpireSolutionUnlocked = true
            if progress.status == .unseen || progress.status == .attempted {
                progress.status = .solvedWithHelp
            }
        }

        // 💡 Create/update SpacedRepetitionCard so this problem enters the review queue.
        //    Pattern mirrors UpdateSpacedRepetitionUseCase lines 13-16.
        //    Quality mapping: solvedIndependently → 4 (minor hesitation),
        //                     everything else    → 3 (serious difficulty — solved with help)
        let quality: Int
        if let progress = progressRepo.getProgress(for: problemId),
           progress.status == .solvedIndependently {
            quality = 4
        } else {
            quality = 3  // ⚠️ Default for solvedWithHelp or missing progress
        }
        var card = progressRepo.getOrCreateCard(for: problemId)
        card = sm2.update(card: card, quality: quality)
        progressRepo.saveCard(card)

        // Ensure the DailyChallenge registers the completion
        if let challenge = progressRepo.getDailyChallenge(for: Date()),
           challenge.problemIds.contains(problemId) {
            progressRepo.markProblemCompleted(challengeId: challenge.id, problemId: problemId)
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("ProgressUpdated"), object: nil)
    }
}
