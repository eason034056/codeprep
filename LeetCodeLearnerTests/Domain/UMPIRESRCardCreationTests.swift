import XCTest
@testable import LeetCodeLearner

/// QA tests for COD-28: verify that completing a problem via Chat/UMPIRE flow
/// correctly creates a SpacedRepetitionCard.
///
/// The bug (COD-24): markUMPIRESolutionDelivered() updated progress.status to
/// .solvedWithHelp but never called getOrCreateCard / sm2.update / saveCard.
/// Users solving problems via UMPIRE got zero SR cards — the primary learning
/// path was completely disconnected from spaced repetition.
///
/// The fix (COD-26): inject SM2Algorithm into EvaluateUserApproachUseCase and
/// add card creation directly in markUMPIRESolutionDelivered().
final class UMPIRESRCardCreationTests: XCTestCase {

    private var mockChatRepo: MockChatRepository!
    private var mockProgressRepo: MockProgressRepository!
    private var sut: EvaluateUserApproachUseCase!

    @MainActor
    override func setUp() {
        super.setUp()
        mockChatRepo = MockChatRepository()
        mockProgressRepo = MockProgressRepository()
        // 💡 Use real SM2Algorithm — we want to verify the actual SM-2 math,
        //    not just that "something" was called.
        sut = EvaluateUserApproachUseCase(
            chatRepo: mockChatRepo,
            progressRepo: mockProgressRepo
        )
    }

    // MARK: - Unit Tests: Card Creation

    @MainActor
    func test_markUMPIRESolutionDelivered_createsCard_whenNoneExists() {
        // Arrange: unseen problem, no existing card
        let progress = TestHelpers.makeProgress(problemId: 1, status: .unseen)
        mockProgressRepo.progressEntries[1] = progress
        XCTAssertNil(mockProgressRepo.getCard(for: 1), "Precondition: no card exists")

        // Act
        sut.markUMPIRESolutionDelivered(problemId: 1)

        // Assert: card was created and saved
        XCTAssertEqual(mockProgressRepo.saveCardCallCount, 1,
                       "saveCard should be called exactly once")
        XCTAssertNotNil(mockProgressRepo.lastSavedCard,
                        "A card should have been saved")
        XCTAssertEqual(mockProgressRepo.lastSavedCard?.problemId, 1)
    }

    @MainActor
    func test_markUMPIRESolutionDelivered_cardHasCorrectSM2State_quality3() {
        // Arrange: unseen problem → will become solvedWithHelp → quality 3
        let progress = TestHelpers.makeProgress(problemId: 1, status: .unseen)
        mockProgressRepo.progressEntries[1] = progress

        // Act
        sut.markUMPIRESolutionDelivered(problemId: 1)

        // Assert: SM-2 with quality 3 on a new card
        // 💡 SM-2 formula: quality >= 3 is "success"
        //    New card (rep=0) → after q=3: rep=1, interval=1
        let card = mockProgressRepo.lastSavedCard!
        XCTAssertEqual(card.repetitionCount, 1,
                       "First successful review should set repetitionCount to 1")
        XCTAssertEqual(card.interval, 1.0,
                       "First success → interval = 1 day")
        XCTAssertEqual(card.lastQualityRating, 3)
        // ⚠️ EF decreases with quality 3: delta = 0.1 - (5-3)*(0.08 + (5-3)*0.02) = -0.14
        // Initial 2.5 - 0.14 = 2.36
        XCTAssertEqual(card.easinessFactor, 2.36, accuracy: 0.01,
                       "Quality 3 should decrease EF from 2.5")
    }

    @MainActor
    func test_markUMPIRESolutionDelivered_usesQuality4_whenAlreadySolvedIndependently() {
        // Arrange: problem already marked as solvedIndependently (e.g., user solved it
        // via Review Queue first, then revisits UMPIRE walkthrough)
        let progress = TestHelpers.makeProgress(problemId: 1, status: .solvedIndependently)
        mockProgressRepo.progressEntries[1] = progress

        // Act
        sut.markUMPIRESolutionDelivered(problemId: 1)

        // Assert: quality 4 mapping
        let card = mockProgressRepo.lastSavedCard!
        XCTAssertEqual(card.lastQualityRating, 4,
                       "solvedIndependently should map to quality 4")
        // SM-2 q=4 on new card: rep=1, interval=1
        // EF delta = 0.1 - (5-4)*(0.08 + (5-4)*0.02) = 0.0
        // EF stays at 2.5
        XCTAssertEqual(card.easinessFactor, 2.5, accuracy: 0.01,
                       "Quality 4 should keep EF at 2.5")
    }

    @MainActor
    func test_markUMPIRESolutionDelivered_usesQuality3_whenAttempted() {
        // Arrange: previously attempted but not solved
        let progress = TestHelpers.makeProgress(problemId: 1, status: .attempted)
        mockProgressRepo.progressEntries[1] = progress

        // Act
        sut.markUMPIRESolutionDelivered(problemId: 1)

        // Assert: status transitions to solvedWithHelp → quality 3
        let card = mockProgressRepo.lastSavedCard!
        XCTAssertEqual(card.lastQualityRating, 3)
    }

    @MainActor
    func test_markUMPIRESolutionDelivered_cardNextReviewDateIsInFuture() {
        let progress = TestHelpers.makeProgress(problemId: 1, status: .unseen)
        mockProgressRepo.progressEntries[1] = progress

        sut.markUMPIRESolutionDelivered(problemId: 1)

        let card = mockProgressRepo.lastSavedCard!
        // After first successful review (q=3), interval=1 day
        // nextReviewDate should be ~1 day from now
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let fiveMinuteBuffer = Calendar.current.date(byAdding: .minute, value: -5, to: tomorrow)!
        XCTAssertGreaterThan(card.nextReviewDate, fiveMinuteBuffer,
                             "Next review should be roughly tomorrow")
    }

    @MainActor
    func test_markUMPIRESolutionDelivered_setsLastReviewDate() {
        let progress = TestHelpers.makeProgress(problemId: 1, status: .unseen)
        mockProgressRepo.progressEntries[1] = progress

        sut.markUMPIRESolutionDelivered(problemId: 1)

        let card = mockProgressRepo.lastSavedCard!
        XCTAssertNotNil(card.lastReviewDate,
                        "lastReviewDate should be set after card update")
        XCTAssertTrue(Calendar.current.isDateInToday(card.lastReviewDate!))
    }

    // MARK: - Duplicate Prevention

    @MainActor
    func test_markUMPIRESolutionDelivered_updatesExistingCard_noDuplicate() {
        // Arrange: problem already has an SR card (e.g., from Review Queue)
        let existingCard = TestHelpers.makeCard(
            problemId: 1,
            nextReviewDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            interval: 6.0,
            easinessFactor: 2.6,
            repetitionCount: 3
        )
        mockProgressRepo.cards = [existingCard]

        let progress = TestHelpers.makeProgress(problemId: 1, status: .solvedWithHelp)
        mockProgressRepo.progressEntries[1] = progress

        // Act
        sut.markUMPIRESolutionDelivered(problemId: 1)

        // Assert: should update the existing card, not create a second one
        XCTAssertEqual(mockProgressRepo.cards.count, 1,
                       "Should not create a duplicate card")
        XCTAssertEqual(mockProgressRepo.saveCardCallCount, 1)

        // The existing card should be updated via SM-2
        let updatedCard = mockProgressRepo.cards.first!
        XCTAssertEqual(updatedCard.problemId, 1)
        XCTAssertEqual(updatedCard.lastQualityRating, 3)
    }

    @MainActor
    func test_markUMPIRESolutionDelivered_calledTwice_doesNotCreateDuplicate() {
        let progress = TestHelpers.makeProgress(problemId: 1, status: .unseen)
        mockProgressRepo.progressEntries[1] = progress

        // Act: solve same problem twice via UMPIRE
        sut.markUMPIRESolutionDelivered(problemId: 1)
        sut.markUMPIRESolutionDelivered(problemId: 1)

        // Assert: still only one card
        XCTAssertEqual(mockProgressRepo.cards.count, 1,
                       "Solving same problem twice should not create duplicate cards")
        XCTAssertEqual(mockProgressRepo.saveCardCallCount, 2,
                       "saveCard should be called twice (once per solve)")
    }

    // MARK: - Multiple Problems

    @MainActor
    func test_markUMPIRESolutionDelivered_multipleProblems_createsCardForEach() {
        // Arrange: 3 unseen problems
        for id in [1, 2, 3] {
            let progress = TestHelpers.makeProgress(problemId: id, status: .unseen)
            mockProgressRepo.progressEntries[id] = progress
        }

        // Act: solve all 3 via UMPIRE
        for id in [1, 2, 3] {
            sut.markUMPIRESolutionDelivered(problemId: id)
        }

        // Assert: 3 distinct cards
        XCTAssertEqual(mockProgressRepo.cards.count, 3)
        let problemIds = Set(mockProgressRepo.cards.map(\.problemId))
        XCTAssertEqual(problemIds, [1, 2, 3],
                       "Each problem should have its own SR card")
        XCTAssertEqual(mockProgressRepo.saveCardCallCount, 3)
    }

    // MARK: - Integration: UMPIRE solve → card appears in review queue

    @MainActor
    func test_integration_umpireSolve_cardAppearsinDueCards() {
        // Arrange: unseen problem
        let progress = TestHelpers.makeProgress(problemId: 42, status: .unseen)
        mockProgressRepo.progressEntries[42] = progress

        // Act: UMPIRE solve
        sut.markUMPIRESolutionDelivered(problemId: 42)

        // Assert: card should be "due" roughly tomorrow (interval=1 after first q=3)
        // So it should NOT be due right now...
        let dueNow = mockProgressRepo.getDueCards(before: Date())
        XCTAssertTrue(dueNow.isEmpty || dueNow.allSatisfy { $0.problemId != 42 },
                      "Freshly reviewed card should not be immediately due")

        // ...but SHOULD be due in 2 days
        let twoDaysFromNow = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        let dueLater = mockProgressRepo.getDueCards(before: twoDaysFromNow)
        XCTAssertTrue(dueLater.contains { $0.problemId == 42 },
                      "Card should appear in review queue after its interval elapses")
    }

    @MainActor
    func test_integration_umpireSolve_thenReviewQueueRate_fullLifecycle() {
        // Full lifecycle: UMPIRE solve creates card → card becomes due → user rates in Review Queue
        let progress = TestHelpers.makeProgress(problemId: 7, status: .unseen)
        mockProgressRepo.progressEntries[7] = progress

        // Step 1: UMPIRE solve → creates card with q=3
        sut.markUMPIRESolutionDelivered(problemId: 7)
        let cardAfterUmpire = mockProgressRepo.getCard(for: 7)!
        XCTAssertEqual(cardAfterUmpire.repetitionCount, 1)
        XCTAssertEqual(cardAfterUmpire.interval, 1.0)

        // Step 2: Simulate Review Queue rating with quality 5 (perfect recall)
        let srUseCase = UpdateSpacedRepetitionUseCase(progressRepo: mockProgressRepo)
        srUseCase.execute(problemId: 7, qualityRating: 5)

        // Assert: card should now have rep=2, interval=6 (second successful review)
        let cardAfterReview = mockProgressRepo.getCard(for: 7)!
        XCTAssertEqual(cardAfterReview.repetitionCount, 2)
        XCTAssertEqual(cardAfterReview.interval, 6.0,
                       "Second success should set interval to 6 days")
        XCTAssertEqual(cardAfterReview.lastQualityRating, 5)
    }

    // MARK: - Review Queue regression: still works independently

    func test_regression_reviewQueueFlow_stillCreatesCards() {
        // The Review Queue flow should remain unaffected by the UMPIRE fix
        let mockRepo = MockProgressRepository()
        let srUseCase = UpdateSpacedRepetitionUseCase(progressRepo: mockRepo)

        let progress = TestHelpers.makeProgress(problemId: 5, status: .attempted)
        mockRepo.progressEntries[5] = progress

        // Act: rate card via Review Queue
        srUseCase.execute(problemId: 5, qualityRating: 4)

        // Assert: card created and saved
        XCTAssertEqual(mockRepo.saveCardCallCount, 1)
        let card = mockRepo.lastSavedCard!
        XCTAssertEqual(card.problemId, 5)
        XCTAssertEqual(card.lastQualityRating, 4)
        XCTAssertEqual(card.repetitionCount, 1)
    }

    // MARK: - Daily Challenge + SR card creation

    @MainActor
    func test_markUMPIRESolutionDelivered_dailyChallenge_bothCardAndChallengeUpdated() {
        // Arrange: problem is part of today's daily challenge
        let challenge = DailyChallenge(
            date: Date(),
            problemIds: [10, 20, 30],
            completedProblemIds: []
        )
        let dateKey = "\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
        mockProgressRepo.dailyChallenges[dateKey] = challenge

        let progress = TestHelpers.makeProgress(problemId: 10, status: .unseen)
        mockProgressRepo.progressEntries[10] = progress

        // Act
        sut.markUMPIRESolutionDelivered(problemId: 10)

        // Assert: BOTH card creation AND daily challenge completion happen
        XCTAssertEqual(mockProgressRepo.saveCardCallCount, 1,
                       "SR card should be created")
        XCTAssertNotNil(mockProgressRepo.getCard(for: 10),
                        "Card should exist for problem 10")

        let updatedChallenge = mockProgressRepo.dailyChallenges[dateKey]!
        XCTAssertTrue(updatedChallenge.completedProblemIds.contains(10),
                      "Daily challenge should also mark problem as completed")
    }

    @MainActor
    func test_markUMPIRESolutionDelivered_notInDailyChallenge_cardStillCreated() {
        // Problem is NOT part of any daily challenge — card should still be created
        let progress = TestHelpers.makeProgress(problemId: 99, status: .unseen)
        mockProgressRepo.progressEntries[99] = progress

        sut.markUMPIRESolutionDelivered(problemId: 99)

        XCTAssertEqual(mockProgressRepo.saveCardCallCount, 1)
        XCTAssertEqual(mockProgressRepo.lastSavedCard?.problemId, 99)
    }

    // MARK: - Edge Cases

    @MainActor
    func test_markUMPIRESolutionDelivered_noProgressEntry_cardStillCreated() {
        // ⚠️ Edge case: progress entry doesn't exist yet (shouldn't happen in
        // normal flow, but test defensive behavior)
        // updateProgress is a no-op if entry doesn't exist, but getOrCreateCard
        // should still create a card

        sut.markUMPIRESolutionDelivered(problemId: 999)

        // Card should still be created even without a progress entry
        XCTAssertEqual(mockProgressRepo.saveCardCallCount, 1,
                       "Card should be created even without a progress entry")
        XCTAssertEqual(mockProgressRepo.lastSavedCard?.problemId, 999)
        // Quality defaults to 3 when progress is nil (can't be solvedIndependently)
        XCTAssertEqual(mockProgressRepo.lastSavedCard?.lastQualityRating, 3)
    }

    @MainActor
    func test_markUMPIRESolutionDelivered_solvedWithHelpStatus_remainsQuality3() {
        // Already solvedWithHelp → re-solving via UMPIRE should still use quality 3
        let progress = TestHelpers.makeProgress(problemId: 1, status: .solvedWithHelp)
        mockProgressRepo.progressEntries[1] = progress

        sut.markUMPIRESolutionDelivered(problemId: 1)

        let card = mockProgressRepo.lastSavedCard!
        XCTAssertEqual(card.lastQualityRating, 3,
                       "solvedWithHelp should still map to quality 3")
    }

    // MARK: - Consistency: both flows produce compatible cards

    @MainActor
    func test_consistency_umpireAndReviewQueue_produceCompatibleCards() {
        // Verify that cards created by UMPIRE flow are structurally identical
        // to cards created by Review Queue flow (same SM-2 state for same quality)

        // UMPIRE path: quality 3
        let progress1 = TestHelpers.makeProgress(problemId: 1, status: .unseen)
        mockProgressRepo.progressEntries[1] = progress1
        sut.markUMPIRESolutionDelivered(problemId: 1)
        let umpireCard = mockProgressRepo.getCard(for: 1)!

        // Review Queue path: quality 3
        let reviewRepo = MockProgressRepository()
        let progress2 = TestHelpers.makeProgress(problemId: 2, status: .attempted)
        reviewRepo.progressEntries[2] = progress2
        let srUseCase = UpdateSpacedRepetitionUseCase(progressRepo: reviewRepo)
        srUseCase.execute(problemId: 2, qualityRating: 3)
        let reviewCard = reviewRepo.getCard(for: 2)!

        // Assert: same SM-2 state (both are first review with quality 3)
        XCTAssertEqual(umpireCard.repetitionCount, reviewCard.repetitionCount,
                       "Same quality on new card should produce same repetitionCount")
        XCTAssertEqual(umpireCard.interval, reviewCard.interval,
                       "Same quality on new card should produce same interval")
        XCTAssertEqual(umpireCard.easinessFactor, reviewCard.easinessFactor, accuracy: 0.001,
                       "Same quality on new card should produce same EF")
        XCTAssertEqual(umpireCard.lastQualityRating, reviewCard.lastQualityRating)
    }
}
