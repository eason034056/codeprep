import XCTest
@testable import LeetCodeLearner

final class ScheduleNotificationsUseCaseTests: XCTestCase {

    private var mockScheduler: MockNotificationScheduler!
    private var sut: ScheduleNotificationsUseCase!

    private let defaultTimes: [DateComponents] = [
        DateComponents(hour: 9, minute: 0),
        DateComponents(hour: 13, minute: 0),
        DateComponents(hour: 19, minute: 0),
    ]

    private let fixedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 27))!

    override func setUp() {
        super.setUp()
        mockScheduler = MockNotificationScheduler()
        sut = ScheduleNotificationsUseCase(notificationManager: mockScheduler)
    }

    // MARK: - Single Day

    func testSingleDay_schedulesThreeNotifications() async {
        let challenges = [makeChallengeEntry(dayOffset: 0, problemCount: 3)]

        await sut.execute(times: defaultTimes, dailyChallenges: challenges)

        XCTAssertEqual(mockScheduler.scheduledNotifications.count, 3)
    }

    func testSingleDay_identifiersAreCorrect() async {
        let challenges = [makeChallengeEntry(dayOffset: 0, problemCount: 3)]

        await sut.execute(times: defaultTimes, dailyChallenges: challenges)

        let identifiers = mockScheduler.scheduledNotifications.map(\.identifier)
        XCTAssertEqual(identifiers, ["daily-d0-s0", "daily-d0-s1", "daily-d0-s2"])
    }

    func testSingleDay_eachBodyContainsDifferentProblem() async {
        let challenges = [makeChallengeEntry(dayOffset: 0, problemCount: 3)]

        await sut.execute(times: defaultTimes, dailyChallenges: challenges)

        let bodies = mockScheduler.scheduledNotifications.map(\.body)
        XCTAssertEqual(Set(bodies).count, 3, "All 3 notification bodies should be different")
        XCTAssertTrue(bodies[0].contains("Problem 1"))
        XCTAssertTrue(bodies[1].contains("Problem 2"))
        XCTAssertTrue(bodies[2].contains("Problem 3"))
    }

    func testRemovesAllPendingBeforeScheduling() async {
        let challenges = [makeChallengeEntry(dayOffset: 0, problemCount: 3)]

        await sut.execute(times: defaultTimes, dailyChallenges: challenges)

        XCTAssertEqual(mockScheduler.removeAllPendingCallCount, 1)
    }

    // MARK: - Multi-Day (7 days)

    func testSevenDays_schedules21Notifications() async {
        let challenges = (0..<7).map { makeChallengeEntry(dayOffset: $0, problemCount: 3) }

        await sut.execute(times: defaultTimes, dailyChallenges: challenges)

        XCTAssertEqual(mockScheduler.scheduledNotifications.count, 21)
    }

    func testSevenDays_identifiersEncoDayAndSlot() async {
        let challenges = (0..<7).map { makeChallengeEntry(dayOffset: $0, problemCount: 3) }

        await sut.execute(times: defaultTimes, dailyChallenges: challenges)

        let identifiers = mockScheduler.scheduledNotifications.map(\.identifier)
        // Spot-check first day and last day
        XCTAssertEqual(identifiers[0], "daily-d0-s0")
        XCTAssertEqual(identifiers[1], "daily-d0-s1")
        XCTAssertEqual(identifiers[2], "daily-d0-s2")
        XCTAssertEqual(identifiers[18], "daily-d6-s0")
        XCTAssertEqual(identifiers[19], "daily-d6-s1")
        XCTAssertEqual(identifiers[20], "daily-d6-s2")
        // All unique
        XCTAssertEqual(Set(identifiers).count, 21)
    }

    func testSevenDays_eachDayHasDifferentContent() async {
        let challenges = (0..<7).map { makeChallengeEntry(dayOffset: $0, problemCount: 3) }

        await sut.execute(times: defaultTimes, dailyChallenges: challenges)

        // Group bodies by day (every 3 notifications = 1 day)
        for day in 0..<7 {
            let startIdx = day * 3
            let dayBodies = Set((startIdx..<startIdx + 3).map { mockScheduler.scheduledNotifications[$0].body })
            XCTAssertEqual(dayBodies.count, 3, "Day \(day) should have 3 different notification bodies")
        }

        // Day 0 and Day 1 should have different content (different problem IDs)
        let day0Body = mockScheduler.scheduledNotifications[0].body
        let day1Body = mockScheduler.scheduledNotifications[3].body
        XCTAssertNotEqual(day0Body, day1Body, "Different days should have different problem content")
    }

    func testDateComponentsIncludeFullDate() async {
        let challenges = [makeChallengeEntry(dayOffset: 0, problemCount: 3)]

        await sut.execute(times: defaultTimes, dailyChallenges: challenges)

        let dc = mockScheduler.scheduledNotifications[0].dateComponents
        XCTAssertEqual(dc.year, 2026)
        XCTAssertEqual(dc.month, 3)
        XCTAssertEqual(dc.day, 27)
        XCTAssertEqual(dc.hour, 9)
        XCTAssertEqual(dc.minute, 0)

        // Second slot same day, different time
        let dc2 = mockScheduler.scheduledNotifications[1].dateComponents
        XCTAssertEqual(dc2.hour, 13)
    }

    func testSevenDays_dateComponentsAdvanceByDay() async {
        let challenges = (0..<7).map { makeChallengeEntry(dayOffset: $0, problemCount: 3) }

        await sut.execute(times: defaultTimes, dailyChallenges: challenges)

        // Day 0, slot 0 → March 27
        XCTAssertEqual(mockScheduler.scheduledNotifications[0].dateComponents.day, 27)
        // Day 1, slot 0 → March 28
        XCTAssertEqual(mockScheduler.scheduledNotifications[3].dateComponents.day, 28)
        // Day 6, slot 0 → April 2
        XCTAssertEqual(mockScheduler.scheduledNotifications[18].dateComponents.month, 4)
        XCTAssertEqual(mockScheduler.scheduledNotifications[18].dateComponents.day, 2)
    }

    func testBadgeCountIsPassedThrough() async {
        let challenges = [makeChallengeEntry(dayOffset: 0, problemCount: 3, pendingCount: 2)]

        await sut.execute(times: defaultTimes, dailyChallenges: challenges)

        for notification in mockScheduler.scheduledNotifications {
            XCTAssertEqual(notification.badge, 2)
        }
    }

    // MARK: - Edge Cases

    func testFewerProblems_usesGenericFallbackBody() async {
        let entry = DailyChallengeEntry(
            date: fixedDate,
            problems: [TestHelpers.makeProblem(id: 1, title: "Two Sum")],
            pendingCount: 3
        )

        await sut.execute(times: defaultTimes, dailyChallenges: [entry])

        XCTAssertTrue(mockScheduler.scheduledNotifications[0].body.contains("Two Sum"))
        XCTAssertEqual(mockScheduler.scheduledNotifications[1].body, "You have problems waiting for you!")
        XCTAssertEqual(mockScheduler.scheduledNotifications[2].body, "You have problems waiting for you!")
    }

    func testZeroProblems_allGenericBodies() async {
        let entry = DailyChallengeEntry(date: fixedDate, problems: [], pendingCount: 0)

        await sut.execute(times: defaultTimes, dailyChallenges: [entry])

        for notification in mockScheduler.scheduledNotifications {
            XCTAssertEqual(notification.body, "You have problems waiting for you!")
        }
    }

    func testEmptyDailyChallenges_schedulesNothing() async {
        await sut.execute(times: defaultTimes, dailyChallenges: [])

        XCTAssertEqual(mockScheduler.scheduledNotifications.count, 0)
        XCTAssertEqual(mockScheduler.removeAllPendingCallCount, 1)
    }

    // MARK: - Helpers

    private func makeChallengeEntry(dayOffset: Int, problemCount: Int, pendingCount: Int = 3) -> DailyChallengeEntry {
        let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: fixedDate)!
        let baseId = dayOffset * 10 + 1
        let difficulties: [Difficulty] = [.easy, .medium, .hard]
        let topics = ProblemTopic.allCases
        let problems = (0..<problemCount).map { i in
            let id = baseId + i
            return TestHelpers.makeProblem(
                id: id,
                title: "Problem \(id)",
                difficulty: difficulties[i % 3],
                topic: topics[i % topics.count]
            )
        }
        return DailyChallengeEntry(date: date, problems: problems, pendingCount: pendingCount)
    }
}
