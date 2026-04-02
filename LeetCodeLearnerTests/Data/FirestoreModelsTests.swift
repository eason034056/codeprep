import XCTest
@testable import LeetCodeLearner

final class FirestoreModelsTests: XCTestCase {

    // MARK: - FirestoreProgress

    func testFirestoreProgress_codableRoundTrip() throws {
        let original = FirestoreProgress(
            progressId: UUID().uuidString,
            problemId: 42,
            statusRaw: "solvedIndependently",
            attemptCount: 3,
            lastAttemptDate: Date(),
            bestApproachConfirmed: true,
            umpireSolutionUnlocked: true,
            notes: "Used two pointers",
            lastModified: Date()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FirestoreProgress.self, from: data)

        XCTAssertEqual(decoded.progressId, original.progressId)
        XCTAssertEqual(decoded.problemId, original.problemId)
        XCTAssertEqual(decoded.statusRaw, original.statusRaw)
        XCTAssertEqual(decoded.attemptCount, original.attemptCount)
        XCTAssertEqual(decoded.bestApproachConfirmed, original.bestApproachConfirmed)
        XCTAssertEqual(decoded.umpireSolutionUnlocked, original.umpireSolutionUnlocked)
        XCTAssertEqual(decoded.notes, original.notes)
    }

    func testFirestoreProgress_nilLastAttemptDate() throws {
        let original = FirestoreProgress(
            progressId: UUID().uuidString,
            problemId: 1,
            statusRaw: "unseen",
            attemptCount: 0,
            lastAttemptDate: nil,
            bestApproachConfirmed: false,
            umpireSolutionUnlocked: false,
            notes: "",
            lastModified: Date()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FirestoreProgress.self, from: data)

        XCTAssertNil(decoded.lastAttemptDate)
        XCTAssertEqual(decoded.statusRaw, "unseen")
    }

    // MARK: - FirestoreCard

    func testFirestoreCard_codableRoundTrip() throws {
        let original = FirestoreCard(
            cardId: UUID().uuidString,
            problemId: 15,
            repetitionCount: 5,
            interval: 14.0,
            easinessFactor: 2.6,
            nextReviewDate: Date(),
            lastReviewDate: Date().addingTimeInterval(-86400),
            lastQualityRating: 4,
            lastModified: Date()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FirestoreCard.self, from: data)

        XCTAssertEqual(decoded.cardId, original.cardId)
        XCTAssertEqual(decoded.problemId, original.problemId)
        XCTAssertEqual(decoded.repetitionCount, original.repetitionCount)
        XCTAssertEqual(decoded.interval, original.interval, accuracy: 0.001)
        XCTAssertEqual(decoded.easinessFactor, original.easinessFactor, accuracy: 0.001)
        XCTAssertEqual(decoded.lastQualityRating, original.lastQualityRating)
    }

    func testFirestoreCard_nilOptionals() throws {
        let original = FirestoreCard(
            cardId: UUID().uuidString,
            problemId: 1,
            repetitionCount: 0,
            interval: 0,
            easinessFactor: 2.5,
            nextReviewDate: Date(),
            lastReviewDate: nil,
            lastQualityRating: nil,
            lastModified: Date()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FirestoreCard.self, from: data)

        XCTAssertNil(decoded.lastReviewDate)
        XCTAssertNil(decoded.lastQualityRating)
    }

    // MARK: - FirestoreDailyChallenge

    func testFirestoreDailyChallenge_codableRoundTrip() throws {
        let original = FirestoreDailyChallenge(
            challengeId: UUID().uuidString,
            date: Date(),
            problemIds: [1, 15, 42],
            completedProblemIds: [1, 42],
            lastModified: Date()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FirestoreDailyChallenge.self, from: data)

        XCTAssertEqual(decoded.challengeId, original.challengeId)
        XCTAssertEqual(decoded.problemIds, [1, 15, 42])
        XCTAssertEqual(decoded.completedProblemIds, [1, 42])
    }

    func testFirestoreDailyChallenge_emptyCompleted() throws {
        let original = FirestoreDailyChallenge(
            challengeId: UUID().uuidString,
            date: Date(),
            problemIds: [1, 2, 3],
            completedProblemIds: [],
            lastModified: Date()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FirestoreDailyChallenge.self, from: data)

        XCTAssertTrue(decoded.completedProblemIds.isEmpty)
    }

    // MARK: - FirestoreChatSession

    func testFirestoreChatSession_codableRoundTrip() throws {
        let original = FirestoreChatSession(
            sessionId: UUID().uuidString,
            problemId: 1,
            createdAt: Date(),
            isUMPIREMode: true,
            lastModified: Date()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FirestoreChatSession.self, from: data)

        XCTAssertEqual(decoded.sessionId, original.sessionId)
        XCTAssertEqual(decoded.problemId, original.problemId)
        XCTAssertEqual(decoded.isUMPIREMode, true)
    }

    // MARK: - FirestoreChatMessage

    func testFirestoreChatMessage_codableRoundTrip() throws {
        let original = FirestoreChatMessage(
            messageId: UUID().uuidString,
            sessionId: UUID().uuidString,
            roleRaw: "assistant",
            content: "Let's think about this problem step by step.",
            timestamp: Date(),
            umpireStepRaw: 2,
            lastModified: Date()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FirestoreChatMessage.self, from: data)

        XCTAssertEqual(decoded.messageId, original.messageId)
        XCTAssertEqual(decoded.sessionId, original.sessionId)
        XCTAssertEqual(decoded.roleRaw, "assistant")
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.umpireStepRaw, 2)
    }

    func testFirestoreChatMessage_nilUmpireStep() throws {
        let original = FirestoreChatMessage(
            messageId: UUID().uuidString,
            sessionId: UUID().uuidString,
            roleRaw: "user",
            content: "I think we should use a hash map",
            timestamp: Date(),
            umpireStepRaw: nil,
            lastModified: Date()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FirestoreChatMessage.self, from: data)

        XCTAssertNil(decoded.umpireStepRaw)
        XCTAssertEqual(decoded.roleRaw, "user")
    }
}
