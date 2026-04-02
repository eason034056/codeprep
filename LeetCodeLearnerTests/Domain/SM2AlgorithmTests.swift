import XCTest
@testable import LeetCodeLearner

final class SM2AlgorithmTests: XCTestCase {

    private var sut: SM2Algorithm!

    override func setUp() {
        super.setUp()
        sut = SM2Algorithm()
    }

    // Test: new card with quality 5 gets interval 1
    func testFirstSuccessfulReview_setsIntervalToOne() {
        var card = makeNewCard()
        card = sut.update(card: card, quality: 5)
        XCTAssertEqual(card.interval, 1.0)
        XCTAssertEqual(card.repetitionCount, 1)
    }

    // Test: second successful review gets interval 6
    func testSecondSuccessfulReview_setsIntervalToSix() {
        var card = makeNewCard()
        card = sut.update(card: card, quality: 5)
        card = sut.update(card: card, quality: 5)
        XCTAssertEqual(card.interval, 6.0)
        XCTAssertEqual(card.repetitionCount, 2)
    }

    // Test: third review uses interval * EF
    func testThirdSuccessfulReview_multipliesIntervalByEF() {
        var card = makeNewCard()
        card = sut.update(card: card, quality: 5)
        card = sut.update(card: card, quality: 5)
        let efBeforeThird = card.easinessFactor
        card = sut.update(card: card, quality: 5)
        XCTAssertEqual(card.interval, 6.0 * efBeforeThird, accuracy: 0.01)
        XCTAssertEqual(card.repetitionCount, 3)
    }

    // Test: quality < 3 resets to interval 1, repetitionCount 0
    func testFailedReview_resetsProgress() {
        var card = makeNewCard()
        card = sut.update(card: card, quality: 5)
        card = sut.update(card: card, quality: 5)
        card = sut.update(card: card, quality: 2) // fail
        XCTAssertEqual(card.interval, 1.0)
        XCTAssertEqual(card.repetitionCount, 0)
    }

    // Test: quality 0 also resets
    func testQualityZero_resetsProgress() {
        var card = makeNewCard()
        card = sut.update(card: card, quality: 4)
        card = sut.update(card: card, quality: 0)
        XCTAssertEqual(card.interval, 1.0)
        XCTAssertEqual(card.repetitionCount, 0)
    }

    // Test: EF never drops below 1.3
    func testEasinessFactorNeverBelowMinimum() {
        var card = makeNewCard()
        // Repeated quality 3 (bare pass) should lower EF but never below 1.3
        for _ in 0..<20 {
            card = sut.update(card: card, quality: 3)
        }
        XCTAssertGreaterThanOrEqual(card.easinessFactor, 1.3)
    }

    // Test: EF increases for high quality
    func testHighQuality_increasesEasinessFactor() {
        var card = makeNewCard()
        let initialEF = card.easinessFactor
        card = sut.update(card: card, quality: 5)
        XCTAssertGreaterThan(card.easinessFactor, initialEF)
    }

    // Test: EF decreases for low quality (but passing)
    func testLowPassingQuality_decreasesEasinessFactor() {
        var card = makeNewCard()
        let initialEF = card.easinessFactor
        card = sut.update(card: card, quality: 3)
        XCTAssertLessThan(card.easinessFactor, initialEF)
    }

    // Test: quality 4 is a correct with hesitation
    func testQualityFour_slightlyDecreasesEF() {
        var card = makeNewCard()
        let initialEF = card.easinessFactor // 2.5
        card = sut.update(card: card, quality: 4)
        // q=4: delta = 0.1 - (5-4)*(0.08 + (5-4)*0.02) = 0.1 - 0.1 = 0
        XCTAssertEqual(card.easinessFactor, initialEF, accuracy: 0.001)
    }

    // Test: lastReviewDate is set
    func testUpdate_setsLastReviewDate() {
        var card = makeNewCard()
        XCTAssertNil(card.lastReviewDate)
        card = sut.update(card: card, quality: 4)
        XCTAssertNotNil(card.lastReviewDate)
    }

    // Test: lastQualityRating is set
    func testUpdate_setsLastQualityRating() {
        var card = makeNewCard()
        card = sut.update(card: card, quality: 3)
        XCTAssertEqual(card.lastQualityRating, 3)
    }

    // Test: nextReviewDate is in the future
    func testUpdate_setsNextReviewDateInFuture() {
        var card = makeNewCard()
        card = sut.update(card: card, quality: 5)
        XCTAssertGreaterThan(card.nextReviewDate, Date())
    }

    // MARK: - Helpers

    private func makeNewCard(problemId: Int = 1) -> SpacedRepetitionCard {
        SpacedRepetitionCard(
            id: UUID(),
            userId: "",
            problemId: problemId,
            repetitionCount: 0,
            interval: 0,
            easinessFactor: 2.5,
            nextReviewDate: Date(),
            lastReviewDate: nil,
            lastQualityRating: nil
        )
    }
}
