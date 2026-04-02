import Foundation

final class EvaluateUserApproachUseCase {
    private let chatRepo: ChatRepositoryProtocol
    private let progressRepo: ProgressRepositoryProtocol

    static let approachConfirmedMarker = "===APPROACH_CONFIRMED==="

    init(chatRepo: ChatRepositoryProtocol, progressRepo: ProgressRepositoryProtocol) {
        self.chatRepo = chatRepo
        self.progressRepo = progressRepo
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
            progress.umpireSolutionUnlocked = true
            if progress.status == .unseen || progress.status == .attempted {
                progress.status = .solvedWithHelp
            }
        }
        
        // Ensure the DailyChallenge registers the completion
        if let challenge = progressRepo.getDailyChallenge(for: Date()),
           challenge.problemIds.contains(problemId) {
            progressRepo.markProblemCompleted(challengeId: challenge.id, problemId: problemId)
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("ProgressUpdated"), object: nil)
    }
}
