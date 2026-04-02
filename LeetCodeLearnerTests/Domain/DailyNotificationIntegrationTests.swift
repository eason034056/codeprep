import XCTest
@testable import LeetCodeLearner

final class DailyNotificationIntegrationTests: XCTestCase {

    private var problemRepo: MockProblemRepository!
    private var progressRepo: MockProgressRepository!
    private var mockScheduler: MockNotificationScheduler!
    private var selectUseCase: SelectDailyProblemsUseCase!
    private var scheduleUseCase: ScheduleNotificationsUseCase!

    private let fixedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 27))!
    private let defaultTimes: [DateComponents] = [
        DateComponents(hour: 9, minute: 0),
        DateComponents(hour: 13, minute: 0),
        DateComponents(hour: 19, minute: 0),
    ]

    override func setUp() {
        super.setUp()
        problemRepo = MockProblemRepository()
        progressRepo = MockProgressRepository()
        mockScheduler = MockNotificationScheduler()
        selectUseCase = SelectDailyProblemsUseCase(problemRepo: problemRepo, progressRepo: progressRepo)
        scheduleUseCase = ScheduleNotificationsUseCase(notificationManager: mockScheduler)
    }

    func testEndToEnd_sevenDaysProducesDistinctNotificationsPerDay() async {
        problemRepo.problems = makeProblems(count: 30)
        let calendar = Calendar.current

        var dailyChallenges: [DailyChallengeEntry] = []
        var excludedIds: Set<Int> = []
        for dayOffset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: fixedDate)!
            let challenge = selectUseCase.execute(learningPath: .grind75, date: date, excluding: excludedIds)
            excludedIds.formUnion(challenge.problemIds)
            let problems = problemRepo.fetchByIds(challenge.problemIds)
            dailyChallenges.append(DailyChallengeEntry(
                date: date,
                problems: problems,
                pendingCount: challenge.remainingCount
            ))
        }

        await scheduleUseCase.execute(times: defaultTimes, dailyChallenges: dailyChallenges)

        // 7 days × 3 slots = 21 notifications
        XCTAssertEqual(mockScheduler.scheduledNotifications.count, 21)

        // Each day's first slot should have a unique body (different problems)
        let firstSlotBodies = stride(from: 0, to: 21, by: 3).map {
            mockScheduler.scheduledNotifications[$0].body
        }
        XCTAssertEqual(Set(firstSlotBodies).count, 7,
                       "Each day's first notification should feature a different problem")
    }

    func testEndToEnd_afterSolvingProblems_futureDaysGetNewOnes() async {
        problemRepo.problems = makeProblems(count: 20)
        let calendar = Calendar.current

        // Day 0: select and record
        let day0Challenge = selectUseCase.execute(learningPath: .grind75, date: fixedDate)
        let day0Problems = Set(day0Challenge.problemIds)

        // Mark day 0's problems as solved
        for id in day0Challenge.problemIds {
            progressRepo.progressEntries[id] = TestHelpers.makeProgress(problemId: id, status: .solvedIndependently)
        }

        // Day 1: should not reuse day 0's solved problems
        let day1Date = calendar.date(byAdding: .day, value: 1, to: fixedDate)!
        let day1Challenge = selectUseCase.execute(learningPath: .grind75, date: day1Date)
        let day1Problems = Set(day1Challenge.problemIds)

        XCTAssertTrue(day0Problems.isDisjoint(with: day1Problems),
                      "After solving day 0's problems, day 1 should select entirely different ones")

        // Schedule both days and verify different notification content
        let entries = [
            DailyChallengeEntry(date: fixedDate, problems: problemRepo.fetchByIds(day0Challenge.problemIds), pendingCount: 3),
            DailyChallengeEntry(date: day1Date, problems: problemRepo.fetchByIds(day1Challenge.problemIds), pendingCount: 3),
        ]
        await scheduleUseCase.execute(times: defaultTimes, dailyChallenges: entries)

        let day0Bodies = Set((0..<3).map { mockScheduler.scheduledNotifications[$0].body })
        let day1Bodies = Set((3..<6).map { mockScheduler.scheduledNotifications[$0].body })
        XCTAssertTrue(day0Bodies.isDisjoint(with: day1Bodies),
                      "Notification content should differ between days")
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
