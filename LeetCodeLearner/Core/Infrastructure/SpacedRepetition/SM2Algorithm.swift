import Foundation

struct SM2Algorithm: Sendable {

    /// Updates a spaced repetition card based on the user's quality rating (0-5).
    /// - Parameters:
    ///   - card: The current card state
    ///   - quality: User's self-assessment rating (0=complete blackout, 5=perfect recall)
    /// - Returns: Updated card with new interval, EF, and next review date
    func update(card: SpacedRepetitionCard, quality: Int) -> SpacedRepetitionCard {
        precondition((0...5).contains(quality), "Quality must be 0-5")

        var updated = card

        if quality < 3 {
            // Failed review: reset progress
            updated.repetitionCount = 0
            updated.interval = 1
        } else {
            // Successful review
            switch updated.repetitionCount {
            case 0:
                updated.interval = 1
            case 1:
                updated.interval = 6
            default:
                updated.interval = updated.interval * updated.easinessFactor
            }
            updated.repetitionCount += 1
        }

        // Update easiness factor using SM-2 formula
        let q = Double(quality)
        let delta = 0.1 - (5.0 - q) * (0.08 + (5.0 - q) * 0.02)
        updated.easinessFactor = max(1.3, updated.easinessFactor + delta)

        // Set review dates
        updated.lastReviewDate = Date()
        updated.lastQualityRating = quality
        updated.nextReviewDate = Calendar.current.date(
            byAdding: .day,
            value: max(1, Int(ceil(updated.interval))),
            to: Date()
        ) ?? Date().addingTimeInterval(86400)

        return updated
    }
}
