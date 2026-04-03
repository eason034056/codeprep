import XCTest
@testable import LeetCodeLearner

/// End-to-end integration tests for the spaced repetition lifecycle.
/// These tests verify the full cycle of card creation → reviews → interval/EF changes
/// using the real SM2Algorithm (no mocks for the algorithm itself).
final class SpacedRepetitionLifecycleTests: XCTestCase {

    private var sm2: SM2Algorithm!

    override func setUp() {
        super.setUp()
        sm2 = SM2Algorithm()
    }

    // MARK: - Full Lifecycle

    /// 💡 SM-2 lifecycle: new card → 5 reviews tracking interval and EF progression.
    ///
    /// Sequence:
    ///   1. New card (rep=0, interval=0, EF=2.5)
    ///   2. Review q=5 → rep=1, interval=1
    ///   3. Review q=5 → rep=2, interval=6
    ///   4. Review q=2 → rep=0, interval=1 (RESET — quality < 3)
    ///   5. Review q=4 → rep=1, interval=1
    ///   6. Review q=5 → rep=2, interval=6
    func testFullLifecycle_newCardThroughMultipleReviews() {
        var card = SpacedRepetitionCard.new(problemId: 1, userId: "test")
        XCTAssertEqual(card.repetitionCount, 0)
        XCTAssertEqual(card.interval, 0)
        XCTAssertEqual(card.easinessFactor, 2.5)

        // Step 1: First review, quality 5 (perfect recall)
        card = sm2.update(card: card, quality: 5)
        XCTAssertEqual(card.repetitionCount, 1)
        XCTAssertEqual(card.interval, 1.0)
        XCTAssertEqual(card.lastQualityRating, 5)

        // Step 2: Second review, quality 5
        card = sm2.update(card: card, quality: 5)
        XCTAssertEqual(card.repetitionCount, 2)
        XCTAssertEqual(card.interval, 6.0)

        // Step 3: Third review, quality 2 (failed — reset!)
        let efBeforeReset = card.easinessFactor
        card = sm2.update(card: card, quality: 2)
        XCTAssertEqual(card.repetitionCount, 0, "Failed review resets repetitionCount to 0")
        XCTAssertEqual(card.interval, 1.0, "Failed review resets interval to 1")
        // ⚠️ EF still changes on failure — it decreases
        XCTAssertLessThan(card.easinessFactor, efBeforeReset)

        // Step 4: Recovery review, quality 4
        card = sm2.update(card: card, quality: 4)
        XCTAssertEqual(card.repetitionCount, 1)
        XCTAssertEqual(card.interval, 1.0, "First success after reset → interval 1")

        // Step 5: Continued recovery, quality 5
        card = sm2.update(card: card, quality: 5)
        XCTAssertEqual(card.repetitionCount, 2)
        XCTAssertEqual(card.interval, 6.0, "Second success after reset → interval 6")
    }

    // MARK: - EF Trajectory

    func testEFTrajectory_acrossMultipleReviews() {
        var card = SpacedRepetitionCard.new(problemId: 1, userId: "test")
        let initialEF = card.easinessFactor  // 2.5

        // Perfect reviews increase EF
        card = sm2.update(card: card, quality: 5)
        let efAfterQ5 = card.easinessFactor
        XCTAssertGreaterThan(efAfterQ5, initialEF, "Quality 5 should increase EF")

        // Another perfect review
        card = sm2.update(card: card, quality: 5)
        let efAfterSecondQ5 = card.easinessFactor
        XCTAssertGreaterThan(efAfterSecondQ5, efAfterQ5, "Consecutive q=5 keeps increasing EF")

        // Mediocre review (q=3) should decrease EF
        card = sm2.update(card: card, quality: 3)
        let efAfterQ3 = card.easinessFactor
        XCTAssertLessThan(efAfterQ3, efAfterSecondQ5, "Quality 3 should decrease EF")

        // 💡 SM-2 formula: delta = 0.1 - (5-q)*(0.08 + (5-q)*0.02)
        //    q=5 → delta = +0.1 (increases)
        //    q=3 → delta = -0.14 (decreases)
        //    q=0 → delta = -0.8 (big decrease, but floored at 1.3)

        // Failed review drops EF further
        card = sm2.update(card: card, quality: 0)
        let efAfterQ0 = card.easinessFactor
        XCTAssertLessThan(efAfterQ0, efAfterQ3, "Quality 0 should decrease EF significantly")

        // EF never goes below 1.3
        XCTAssertGreaterThanOrEqual(efAfterQ0, 1.3, "EF minimum is 1.3")
    }

    // MARK: - getDueCards Verification

    func testGetDueCards_correctlyIdentifiesOverdueCards() {
        // Arrange: simulate cards at different stages
        let progressRepo = MockProgressRepository()
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let twoDaysFromNow = Calendar.current.date(byAdding: .day, value: 2, to: now)!

        // Card 1: overdue (should be due)
        let card1 = TestHelpers.makeCard(problemId: 1, nextReviewDate: yesterday)
        // Card 2: not yet due (tomorrow)
        let card2 = TestHelpers.makeCard(problemId: 2, nextReviewDate: tomorrow)
        // Card 3: not yet due (2 days from now)
        let card3 = TestHelpers.makeCard(problemId: 3, nextReviewDate: twoDaysFromNow)

        progressRepo.cards = [card1, card2, card3]

        // Act
        let dueCards = progressRepo.getDueCards(before: now)

        // Assert: only card1 is overdue
        XCTAssertEqual(dueCards.count, 1)
        XCTAssertEqual(dueCards.first?.problemId, 1)

        // Now simulate time passing — after reviewing card1, check again later
        let updatedCard1 = sm2.update(card: card1, quality: 5)
        // After a q=5 review with rep=1, nextReviewDate should be ~1 day from now
        progressRepo.saveCard(updatedCard1)

        // Card1 should no longer be due immediately after review
        let dueAfterReview = progressRepo.getDueCards(before: now)
        // 💡 The updated card's nextReviewDate is tomorrow, so it's no longer due "before now"
        XCTAssertTrue(
            dueAfterReview.allSatisfy { $0.problemId != 1 } || dueAfterReview.isEmpty,
            "Reviewed card should not be immediately due again"
        )
    }

    // MARK: - Multi-Card Ordering

    func testMultiCardScenario_differentDueDates_allReturnedWhenOverdue() {
        let progressRepo = MockProgressRepository()
        let now = Date()

        // Create 3 cards with different overdue dates
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: now)!
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        progressRepo.cards = [
            TestHelpers.makeCard(problemId: 10, nextReviewDate: oneDayAgo),
            TestHelpers.makeCard(problemId: 20, nextReviewDate: threeDaysAgo),
            TestHelpers.makeCard(problemId: 30, nextReviewDate: twoDaysAgo)
        ]

        // Act
        let dueCards = progressRepo.getDueCards(before: now)

        // Assert: all 3 cards are due
        XCTAssertEqual(dueCards.count, 3)
        let problemIds = Set(dueCards.map(\.problemId))
        XCTAssertEqual(problemIds, [10, 20, 30])

        // Simulate reviewing them one by one with different qualities
        var card20 = dueCards.first { $0.problemId == 20 }!
        card20 = sm2.update(card: card20, quality: 5)  // Perfect
        progressRepo.saveCard(card20)

        var card30 = dueCards.first { $0.problemId == 30 }!
        card30 = sm2.update(card: card30, quality: 3)  // Barely pass
        progressRepo.saveCard(card30)

        var card10 = dueCards.first { $0.problemId == 10 }!
        card10 = sm2.update(card: card10, quality: 1)  // Failed
        progressRepo.saveCard(card10)

        // After all reviews, check: cards with q>=3 should have future nextReviewDate
        let dueAfterReviews = progressRepo.getDueCards(before: now)
        // Card 10 (q=1, failed) gets interval=1, nextReviewDate = tomorrow → not due now
        // Card 20 (q=5) gets interval=1, nextReviewDate = tomorrow → not due now
        // Card 30 (q=3) gets interval=1, nextReviewDate = tomorrow → not due now
        XCTAssertEqual(dueAfterReviews.count, 0, "All reviewed cards should have future review dates")
    }
}
