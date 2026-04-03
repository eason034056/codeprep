import XCTest
@testable import LeetCodeLearner

/// QA tests for COD-17: verify that markUMPIRESolutionDelivered sets lastAttemptDate
/// so the streak pipeline counts UMPIRE solves.
///
/// The bug: markUMPIRESolutionDelivered() set status to .solvedWithHelp but never
/// set lastAttemptDate. Since getCompletionDates() uses compactMap on lastAttemptDate,
/// these solves were invisible to StreakCalculator.
final class StreakCountingAfterUMPIRETests: XCTestCase {

    private var mockChatRepo: MockChatRepository!
    private var mockProgressRepo: MockProgressRepository!
    private var sut: EvaluateUserApproachUseCase!

    @MainActor
    override func setUp() {
        super.setUp()
        mockChatRepo = MockChatRepository()
        mockProgressRepo = MockProgressRepository()
        sut = EvaluateUserApproachUseCase(
            chatRepo: mockChatRepo,
            progressRepo: mockProgressRepo
        )
    }

    // MARK: - Unit Tests: markUMPIRESolutionDelivered

    @MainActor
    func test_markUMPIRESolutionDelivered_setsLastAttemptDate() {
        // Arrange: unseen problem with nil lastAttemptDate
        let progress = TestHelpers.makeProgress(problemId: 1, status: .unseen)
        XCTAssertNil(progress.lastAttemptDate, "Precondition: lastAttemptDate should be nil")
        mockProgressRepo.progressEntries[1] = progress

        // Act
        sut.markUMPIRESolutionDelivered(problemId: 1)

        // Assert: the fix should set lastAttemptDate to a non-nil Date
        let updated = mockProgressRepo.progressEntries[1]!
        XCTAssertNotNil(updated.lastAttemptDate,
                        "lastAttemptDate must be set after UMPIRE solve — this is the COD-17 fix")
    }

    @MainActor
    func test_markUMPIRESolutionDelivered_lastAttemptDateIsToday() {
        let progress = TestHelpers.makeProgress(problemId: 1)
        mockProgressRepo.progressEntries[1] = progress

        sut.markUMPIRESolutionDelivered(problemId: 1)

        let updated = mockProgressRepo.progressEntries[1]!
        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDateInToday(updated.lastAttemptDate!),
                      "lastAttemptDate should be today's date")
    }

    @MainActor
    func test_markUMPIRESolutionDelivered_setsUmpireSolutionUnlocked() {
        let progress = TestHelpers.makeProgress(problemId: 1)
        mockProgressRepo.progressEntries[1] = progress

        sut.markUMPIRESolutionDelivered(problemId: 1)

        let updated = mockProgressRepo.progressEntries[1]!
        XCTAssertTrue(updated.umpireSolutionUnlocked)
    }

    @MainActor
    func test_markUMPIRESolutionDelivered_setsStatusToSolvedWithHelp_whenUnseen() {
        let progress = TestHelpers.makeProgress(problemId: 1, status: .unseen)
        mockProgressRepo.progressEntries[1] = progress

        sut.markUMPIRESolutionDelivered(problemId: 1)

        let updated = mockProgressRepo.progressEntries[1]!
        XCTAssertEqual(updated.status, .solvedWithHelp)
    }

    @MainActor
    func test_markUMPIRESolutionDelivered_setsStatusToSolvedWithHelp_whenAttempted() {
        let progress = TestHelpers.makeProgress(problemId: 1, status: .attempted)
        mockProgressRepo.progressEntries[1] = progress

        sut.markUMPIRESolutionDelivered(problemId: 1)

        let updated = mockProgressRepo.progressEntries[1]!
        XCTAssertEqual(updated.status, .solvedWithHelp)
    }

    @MainActor
    func test_markUMPIRESolutionDelivered_preservesStatus_whenAlreadySolvedIndependently() {
        let progress = TestHelpers.makeProgress(problemId: 1, status: .solvedIndependently)
        mockProgressRepo.progressEntries[1] = progress

        sut.markUMPIRESolutionDelivered(problemId: 1)

        let updated = mockProgressRepo.progressEntries[1]!
        XCTAssertEqual(updated.status, .solvedIndependently,
                       "Should not downgrade from solvedIndependently to solvedWithHelp")
    }

    @MainActor
    func test_markUMPIRESolutionDelivered_updatesLastAttemptDate_whenResolving() {
        // A problem already solved yesterday — re-solving today should update the date
        var progress = TestHelpers.makeProgress(problemId: 1, status: .solvedWithHelp)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        progress.lastAttemptDate = yesterday
        mockProgressRepo.progressEntries[1] = progress

        sut.markUMPIRESolutionDelivered(problemId: 1)

        let updated = mockProgressRepo.progressEntries[1]!
        XCTAssertTrue(Calendar.current.isDateInToday(updated.lastAttemptDate!),
                      "Re-solving should update lastAttemptDate to today")
    }

    // MARK: - Integration Test: UMPIRE solve → streak pipeline

    @MainActor
    func test_integration_umpireSolve_appearsInStreakCalculation() {
        // Arrange: fresh unseen problem
        let progress = TestHelpers.makeProgress(problemId: 42, status: .unseen)
        mockProgressRepo.progressEntries[42] = progress

        // Act: UMPIRE solve
        sut.markUMPIRESolutionDelivered(problemId: 42)

        // Simulate getCompletionDates() like the real repo does:
        // filter solved + compactMap lastAttemptDate
        let completionDates = mockProgressRepo.getAllProgress().compactMap { p -> Date? in
            guard p.status == .solvedWithHelp || p.status == .solvedIndependently else {
                return nil
            }
            return p.lastAttemptDate
        }

        // Assert: StreakCalculator should count this as a streak of 1
        let streak = StreakCalculator.calculateStreak(from: completionDates)
        XCTAssertGreaterThanOrEqual(streak, 1,
                                     "After UMPIRE solve, streak should be >= 1")
    }

    @MainActor
    func test_integration_multipleUmpireSolves_sameDayCountAsOne() {
        // Solve 3 problems via UMPIRE on the same day
        for id in [1, 2, 3] {
            let progress = TestHelpers.makeProgress(problemId: id, status: .unseen)
            mockProgressRepo.progressEntries[id] = progress
            sut.markUMPIRESolutionDelivered(problemId: id)
        }

        let completionDates = mockProgressRepo.getAllProgress().compactMap { p -> Date? in
            guard p.status == .solvedWithHelp || p.status == .solvedIndependently else {
                return nil
            }
            return p.lastAttemptDate
        }

        let streak = StreakCalculator.calculateStreak(from: completionDates)
        XCTAssertEqual(streak, 1,
                       "Multiple UMPIRE solves on same day should count as streak of 1")
    }

    // MARK: - Regression: markApproachConfirmed does NOT set lastAttemptDate

    @MainActor
    func test_markApproachConfirmed_doesNotSetLastAttemptDate() {
        // markApproachConfirmed should NOT set lastAttemptDate — only the full solution does
        let session = ChatSession(problemId: 1)
        mockChatRepo.stub(session: session)

        let progress = TestHelpers.makeProgress(problemId: 1)
        mockProgressRepo.progressEntries[1] = progress

        sut.markApproachConfirmed(sessionId: session.id, problemId: 1)

        let updated = mockProgressRepo.progressEntries[1]!
        XCTAssertNil(updated.lastAttemptDate,
                     "Approach confirmation should NOT set lastAttemptDate — only full UMPIRE solve does")
    }

    // MARK: - Regression: SR flow still sets lastAttemptDate

    func test_regression_spacedRepetitionUseCase_setsLastAttemptDate() {
        let mockRepo = MockProgressRepository()
        let srUseCase = UpdateSpacedRepetitionUseCase(
            progressRepo: mockRepo
        )

        let progress = TestHelpers.makeProgress(problemId: 10, status: .attempted)
        mockRepo.progressEntries[10] = progress

        srUseCase.execute(problemId: 10, qualityRating: 5)

        let updated = mockRepo.progressEntries[10]!
        XCTAssertNotNil(updated.lastAttemptDate,
                        "Regression: SR flow must still set lastAttemptDate")
        XCTAssertTrue(Calendar.current.isDateInToday(updated.lastAttemptDate!))
    }

    // MARK: - DailyChallenge completion integration

    @MainActor
    func test_markUMPIRESolutionDelivered_marksDailyChallengeCompleted() {
        // Set up a daily challenge containing the problem
        let challenge = DailyChallenge(
            date: Date(),
            problemIds: [1, 2, 3],
            completedProblemIds: []
        )
        let dateKey = "\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
        mockProgressRepo.dailyChallenges[dateKey] = challenge

        let progress = TestHelpers.makeProgress(problemId: 1)
        mockProgressRepo.progressEntries[1] = progress

        sut.markUMPIRESolutionDelivered(problemId: 1)

        // Verify the challenge was updated with the completion
        let updatedChallenge = mockProgressRepo.dailyChallenges[dateKey]!
        XCTAssertTrue(updatedChallenge.completedProblemIds.contains(1),
                      "UMPIRE solve should mark the problem as completed in daily challenge")
    }
}
