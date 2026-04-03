import XCTest
@testable import LeetCodeLearner

final class ProgressMapperTests: XCTestCase {

    // MARK: - cardToDomain

    func testCardToDomain_mapsAllFieldsCorrectly() {
        // Arrange: create an SDSpacedRepetitionCard with known values
        let cardId = UUID()
        let reviewDate = Date(timeIntervalSince1970: 1_700_000_000)
        let nextDate = Date(timeIntervalSince1970: 1_700_100_000)

        let sd = SDSpacedRepetitionCard(
            cardId: cardId,
            userId: "user-123",
            problemId: 42,
            repetitionCount: 3,
            interval: 6.0,
            easinessFactor: 2.6,
            nextReviewDate: nextDate,
            lastReviewDate: reviewDate,
            lastQualityRating: 5
        )

        // Act
        let domain = ProgressMapper.cardToDomain(sd)

        // Assert: every field maps 1:1
        XCTAssertEqual(domain.id, cardId)
        XCTAssertEqual(domain.userId, "user-123")
        XCTAssertEqual(domain.problemId, 42)
        XCTAssertEqual(domain.repetitionCount, 3)
        XCTAssertEqual(domain.interval, 6.0)
        XCTAssertEqual(domain.easinessFactor, 2.6)
        XCTAssertEqual(domain.nextReviewDate, nextDate)
        XCTAssertEqual(domain.lastReviewDate, reviewDate)
        XCTAssertEqual(domain.lastQualityRating, 5)
    }

    // MARK: - cardToSwiftData

    func testCardToSwiftData_mapsAllFieldsCorrectly() {
        // Arrange: domain card with known values
        let cardId = UUID()
        let reviewDate = Date(timeIntervalSince1970: 1_700_000_000)
        let nextDate = Date(timeIntervalSince1970: 1_700_100_000)

        let domain = SpacedRepetitionCard(
            id: cardId,
            userId: "user-456",
            problemId: 99,
            repetitionCount: 2,
            interval: 12.5,
            easinessFactor: 2.3,
            nextReviewDate: nextDate,
            lastReviewDate: reviewDate,
            lastQualityRating: 4
        )

        // Act
        let sd = ProgressMapper.cardToSwiftData(domain)

        // Assert: every field maps 1:1
        // 💡 Note: SD model uses `cardId` instead of `id`
        XCTAssertEqual(sd.cardId, cardId)
        XCTAssertEqual(sd.userId, "user-456")
        XCTAssertEqual(sd.problemId, 99)
        XCTAssertEqual(sd.repetitionCount, 2)
        XCTAssertEqual(sd.interval, 12.5)
        XCTAssertEqual(sd.easinessFactor, 2.3)
        XCTAssertEqual(sd.nextReviewDate, nextDate)
        XCTAssertEqual(sd.lastReviewDate, reviewDate)
        XCTAssertEqual(sd.lastQualityRating, 4)
    }

    // MARK: - Roundtrip

    func testRoundtrip_domainToSwiftDataToDomain_preservesAllFields() {
        // Arrange: a fully-populated domain card
        let cardId = UUID()
        let reviewDate = Date(timeIntervalSince1970: 1_700_000_000)
        let nextDate = Date(timeIntervalSince1970: 1_700_100_000)

        let original = SpacedRepetitionCard(
            id: cardId,
            userId: "roundtrip-user",
            problemId: 7,
            repetitionCount: 5,
            interval: 15.0,
            easinessFactor: 2.8,
            nextReviewDate: nextDate,
            lastReviewDate: reviewDate,
            lastQualityRating: 3
        )

        // Act: domain → SwiftData → domain
        let sd = ProgressMapper.cardToSwiftData(original)
        let roundtripped = ProgressMapper.cardToDomain(sd)

        // Assert: every field survives the roundtrip
        XCTAssertEqual(roundtripped.id, original.id)
        XCTAssertEqual(roundtripped.userId, original.userId)
        XCTAssertEqual(roundtripped.problemId, original.problemId)
        XCTAssertEqual(roundtripped.repetitionCount, original.repetitionCount)
        XCTAssertEqual(roundtripped.interval, original.interval)
        XCTAssertEqual(roundtripped.easinessFactor, original.easinessFactor)
        XCTAssertEqual(roundtripped.nextReviewDate, original.nextReviewDate)
        XCTAssertEqual(roundtripped.lastReviewDate, original.lastReviewDate)
        XCTAssertEqual(roundtripped.lastQualityRating, original.lastQualityRating)
    }

    func testRoundtrip_nilOptionalFields_preservedThroughRoundtrip() {
        // Arrange: card with nil lastReviewDate and lastQualityRating
        // ⚠️ This is the state of a brand-new card that hasn't been reviewed yet
        let cardId = UUID()
        let nextDate = Date(timeIntervalSince1970: 1_700_100_000)

        let original = SpacedRepetitionCard(
            id: cardId,
            userId: "new-user",
            problemId: 1,
            repetitionCount: 0,
            interval: 0.0,
            easinessFactor: 2.5,
            nextReviewDate: nextDate,
            lastReviewDate: nil,
            lastQualityRating: nil
        )

        // Act: domain → SwiftData → domain
        let sd = ProgressMapper.cardToSwiftData(original)
        let roundtripped = ProgressMapper.cardToDomain(sd)

        // Assert: nil fields stay nil
        XCTAssertNil(roundtripped.lastReviewDate)
        XCTAssertNil(roundtripped.lastQualityRating)
        // And all other fields still match
        XCTAssertEqual(roundtripped.id, original.id)
        XCTAssertEqual(roundtripped.problemId, original.problemId)
        XCTAssertEqual(roundtripped.repetitionCount, 0)
        XCTAssertEqual(roundtripped.interval, 0.0)
        XCTAssertEqual(roundtripped.easinessFactor, 2.5)
    }
}
