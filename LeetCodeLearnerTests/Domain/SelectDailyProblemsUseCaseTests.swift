import XCTest
@testable import LeetCodeLearner

final class SelectDailyProblemsUseCaseTests: XCTestCase {

    private var problemRepo: MockProblemRepository!
    private var progressRepo: MockProgressRepository!
    private var sut: SelectDailyProblemsUseCase!
    private let fixedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 27))!

    override func setUp() {
        super.setUp()
        problemRepo = MockProblemRepository()
        progressRepo = MockProgressRepository()
        sut = SelectDailyProblemsUseCase(problemRepo: problemRepo, progressRepo: progressRepo)
    }

    // MARK: - Basic Selection

    func testSelectsExactlyThreeProblems() {
        problemRepo.problems = makeProblems(count: 10)

        let challenge = sut.execute(learningPath: .grind75, date: fixedDate)

        XCTAssertEqual(challenge.problemIds.count, 3)
    }

    func testSelectedProblemsAreAllDifferent() {
        problemRepo.problems = makeProblems(count: 10)

        let challenge = sut.execute(learningPath: .grind75, date: fixedDate)

        XCTAssertEqual(Set(challenge.problemIds).count, 3, "All 3 problem IDs should be unique")
    }

    // MARK: - Slot Strategies

    func testSlot1_selectsMostOverdueSRCard() {
        let problems = makeProblems(count: 5)
        problemRepo.problems = problems

        // Card for problem 3 is most overdue (earliest nextReviewDate)
        let veryOverdue = Calendar.current.date(byAdding: .day, value: -10, to: fixedDate)!
        let slightlyOverdue = Calendar.current.date(byAdding: .day, value: -1, to: fixedDate)!
        progressRepo.cards = [
            TestHelpers.makeCard(problemId: 3, nextReviewDate: veryOverdue),
            TestHelpers.makeCard(problemId: 1, nextReviewDate: slightlyOverdue),
        ]

        let challenge = sut.execute(learningPath: .grind75, date: fixedDate)

        XCTAssertEqual(challenge.problemIds.first, 3, "Slot 1 should be the most overdue SR card")
    }

    func testSlot2_selectsNextInLearningPath() {
        // Problem 1 (week 1, order 1) is solved; problem 2 (week 1, order 2) should be next
        problemRepo.problems = [
            TestHelpers.makeProblem(id: 1, grind75Week: 1, grind75Order: 1),
            TestHelpers.makeProblem(id: 2, grind75Week: 1, grind75Order: 2),
            TestHelpers.makeProblem(id: 3, grind75Week: 2, grind75Order: 1),
            TestHelpers.makeProblem(id: 4, grind75Week: 2, grind75Order: 2),
            TestHelpers.makeProblem(id: 5, grind75Week: 3, grind75Order: 1),
        ]
        progressRepo.progressEntries[1] = TestHelpers.makeProgress(problemId: 1, status: .solvedIndependently)

        let challenge = sut.execute(learningPath: .grind75, date: fixedDate)

        XCTAssertTrue(challenge.problemIds.contains(2), "Slot 2 should pick the next unsolved problem in learning path")
    }

    func testSlot3_selectsWeakestTopicProblem() {
        // Topic A: 3 attempted, 0 solved (0% rate) — weakest
        // Topic B: 2 attempted, 2 solved (100% rate)
        let topicA: ProblemTopic = .dynamicProgramming
        let topicB: ProblemTopic = .arraysAndHashing

        problemRepo.problems = [
            TestHelpers.makeProblem(id: 1, topic: topicA, grind75Week: 1, grind75Order: 1),
            TestHelpers.makeProblem(id: 2, topic: topicA, grind75Week: 1, grind75Order: 2),
            TestHelpers.makeProblem(id: 3, topic: topicA, grind75Week: 1, grind75Order: 3),
            TestHelpers.makeProblem(id: 4, topic: topicA, grind75Week: 2, grind75Order: 1),  // unseen, should be picked
            TestHelpers.makeProblem(id: 5, topic: topicB, grind75Week: 2, grind75Order: 2),
            TestHelpers.makeProblem(id: 6, topic: topicB, grind75Week: 3, grind75Order: 1),
        ]

        // Topic A: attempted but not solved
        progressRepo.progressEntries[1] = TestHelpers.makeProgress(problemId: 1, status: .attempted, attemptCount: 2)
        progressRepo.progressEntries[2] = TestHelpers.makeProgress(problemId: 2, status: .attempted, attemptCount: 1)
        progressRepo.progressEntries[3] = TestHelpers.makeProgress(problemId: 3, status: .solvedWithHelp, attemptCount: 3)
        // Topic B: solved
        progressRepo.progressEntries[5] = TestHelpers.makeProgress(problemId: 5, status: .solvedIndependently, attemptCount: 1)
        progressRepo.progressEntries[6] = TestHelpers.makeProgress(problemId: 6, status: .solvedIndependently, attemptCount: 1)

        let challenge = sut.execute(learningPath: .grind75, date: fixedDate)

        XCTAssertTrue(challenge.problemIds.contains(4), "Slot 3 should pick unseen problem from weakest topic (dynamicProgramming)")
    }

    // MARK: - Caching

    func testCaching_sameDayReturnsSameChallenge() {
        problemRepo.problems = makeProblems(count: 10)

        let first = sut.execute(learningPath: .grind75, date: fixedDate)
        let second = sut.execute(learningPath: .grind75, date: fixedDate)

        XCTAssertEqual(first.problemIds, second.problemIds, "Same day should return cached challenge")
        XCTAssertEqual(progressRepo.saveDailyChallengeCallCount, 1, "Should only save once, second call uses cache")
    }

    func testNewDay_selectsFreshChallenge() {
        problemRepo.problems = makeProblems(count: 10)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: fixedDate)!

        let day1 = sut.execute(learningPath: .grind75, date: fixedDate)
        let day2 = sut.execute(learningPath: .grind75, date: tomorrow)

        XCTAssertNotEqual(day1.date, day2.date, "Different days should produce different challenge dates")
        XCTAssertEqual(progressRepo.saveDailyChallengeCallCount, 2, "Each day should save its own challenge")
    }

    func testConsecutiveDays_differentSelectionsAfterProgress() {
        problemRepo.problems = makeProblems(count: 10)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: fixedDate)!

        let day1 = sut.execute(learningPath: .grind75, date: fixedDate)

        // Mark day 1's problems as solved
        for id in day1.problemIds {
            progressRepo.progressEntries[id] = TestHelpers.makeProgress(problemId: id, status: .solvedIndependently)
        }

        let day2 = sut.execute(learningPath: .grind75, date: tomorrow)

        let overlap = Set(day1.problemIds).intersection(Set(day2.problemIds))
        XCTAssertTrue(overlap.isEmpty, "After solving day 1's problems, day 2 should select entirely different ones")
    }

    // MARK: - Edge Cases

    func testFewerThanThreeProblems_oneProblem() {
        problemRepo.problems = [TestHelpers.makeProblem(id: 1)]

        let challenge = sut.execute(learningPath: .grind75, date: fixedDate)

        XCTAssertEqual(challenge.problemIds.count, 1)
        XCTAssertEqual(challenge.problemIds, [1])
    }

    func testFewerThanThreeProblems_twoProblems() {
        problemRepo.problems = [
            TestHelpers.makeProblem(id: 1),
            TestHelpers.makeProblem(id: 2, grind75Week: 1, grind75Order: 2),
        ]

        let challenge = sut.execute(learningPath: .grind75, date: fixedDate)

        XCTAssertEqual(challenge.problemIds.count, 2)
        XCTAssertEqual(Set(challenge.problemIds).count, 2, "Both IDs should be unique")
    }

    func testZeroProblems() {
        problemRepo.problems = []

        let challenge = sut.execute(learningPath: .grind75, date: fixedDate)

        XCTAssertTrue(challenge.problemIds.isEmpty)
    }

    func testAllProblemsSolved_stillSelectsThreeDistinct() {
        let problems = makeProblems(count: 5)
        problemRepo.problems = problems
        for p in problems {
            progressRepo.progressEntries[p.id] = TestHelpers.makeProgress(problemId: p.id, status: .solvedIndependently)
        }

        let challenge = sut.execute(learningPath: .grind75, date: fixedDate)

        XCTAssertEqual(challenge.problemIds.count, 3)
        XCTAssertEqual(Set(challenge.problemIds).count, 3, "All 3 should be unique even when all are solved")
    }

    func testOverlappingSlotCandidates_noDuplicates() {
        // Problem 1 is: most overdue SR card, next in learning path, AND in weakest topic
        problemRepo.problems = [
            TestHelpers.makeProblem(id: 1, topic: .dynamicProgramming, grind75Week: 1, grind75Order: 1),
            TestHelpers.makeProblem(id: 2, topic: .arraysAndHashing, grind75Week: 1, grind75Order: 2),
            TestHelpers.makeProblem(id: 3, topic: .trees, grind75Week: 2, grind75Order: 1),
            TestHelpers.makeProblem(id: 4, topic: .dynamicProgramming, grind75Week: 2, grind75Order: 2),
        ]

        let overdue = Calendar.current.date(byAdding: .day, value: -5, to: fixedDate)!
        progressRepo.cards = [
            TestHelpers.makeCard(problemId: 1, nextReviewDate: overdue),
        ]

        let challenge = sut.execute(learningPath: .grind75, date: fixedDate)

        XCTAssertEqual(Set(challenge.problemIds).count, challenge.problemIds.count,
                        "No duplicates even when one problem is eligible for multiple slots")
        XCTAssertTrue(challenge.problemIds.contains(1), "Problem 1 should be selected (most overdue)")
    }

    // MARK: - Helpers

    private func makeProblems(count: Int) -> [Problem] {
        let difficulties: [Difficulty] = [.easy, .medium, .hard]
        let topics = ProblemTopic.allCases
        return (1...count).map { i in
            let diff = difficulties[i % 3]
            let topic = topics[i % topics.count]
            let week = (i - 1) / 3 + 1
            let order = (i - 1) % 3 + 1
            return TestHelpers.makeProblem(
                id: i,
                title: "Problem \(i)",
                difficulty: diff,
                topic: topic,
                grind75Week: week,
                grind75Order: order
            )
        }
    }
}
