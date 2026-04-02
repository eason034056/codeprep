import Foundation

enum ProgressMapper {
    // UserProblemProgress
    static func toDomain(_ sd: SDUserProblemProgress) -> UserProblemProgress? {
        guard let status = ProblemStatus(rawValue: sd.statusRaw) else { return nil }
        return UserProblemProgress(
            id: sd.progressId,
            userId: sd.userId,
            problemId: sd.problemId,
            status: status,
            attemptCount: sd.attemptCount,
            lastAttemptDate: sd.lastAttemptDate,
            bestApproachConfirmed: sd.bestApproachConfirmed,
            umpireSolutionUnlocked: sd.umpireSolutionUnlocked,
            notes: sd.notes
        )
    }

    static func toSwiftData(_ progress: UserProblemProgress) -> SDUserProblemProgress {
        SDUserProblemProgress(
            progressId: progress.id,
            userId: progress.userId,
            problemId: progress.problemId,
            statusRaw: progress.status.rawValue,
            attemptCount: progress.attemptCount,
            lastAttemptDate: progress.lastAttemptDate,
            bestApproachConfirmed: progress.bestApproachConfirmed,
            umpireSolutionUnlocked: progress.umpireSolutionUnlocked,
            notes: progress.notes
        )
    }

    // SpacedRepetitionCard
    static func cardToDomain(_ sd: SDSpacedRepetitionCard) -> SpacedRepetitionCard {
        SpacedRepetitionCard(
            id: sd.cardId,
            userId: sd.userId,
            problemId: sd.problemId,
            repetitionCount: sd.repetitionCount,
            interval: sd.interval,
            easinessFactor: sd.easinessFactor,
            nextReviewDate: sd.nextReviewDate,
            lastReviewDate: sd.lastReviewDate,
            lastQualityRating: sd.lastQualityRating
        )
    }

    static func cardToSwiftData(_ card: SpacedRepetitionCard) -> SDSpacedRepetitionCard {
        SDSpacedRepetitionCard(
            cardId: card.id,
            userId: card.userId,
            problemId: card.problemId,
            repetitionCount: card.repetitionCount,
            interval: card.interval,
            easinessFactor: card.easinessFactor,
            nextReviewDate: card.nextReviewDate,
            lastReviewDate: card.lastReviewDate,
            lastQualityRating: card.lastQualityRating
        )
    }

    // DailyChallenge
    static func challengeToDomain(_ sd: SDDailyChallenge) -> DailyChallenge {
        DailyChallenge(
            id: sd.challengeId,
            userId: sd.userId,
            date: sd.date,
            problemIds: sd.problemIds,
            completedProblemIds: Set(sd.completedProblemIds)
        )
    }

    static func challengeToSwiftData(_ challenge: DailyChallenge) -> SDDailyChallenge {
        SDDailyChallenge(
            challengeId: challenge.id,
            userId: challenge.userId,
            date: challenge.date,
            problemIds: challenge.problemIds,
            completedProblemIds: Array(challenge.completedProblemIds)
        )
    }
}
