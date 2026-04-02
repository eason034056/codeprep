import XCTest
@testable import LeetCodeLearner

final class StreakCalculatorTests: XCTestCase {

    private let calendar = Calendar.current
    private let today = Calendar.current.startOfDay(for: Date())

    private func daysAgo(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: -n, to: today)!
    }

    // MARK: - Empty / No Data

    func testEmptyDates_returnsZero() {
        XCTAssertEqual(StreakCalculator.calculateStreak(from: [], referenceDate: today), 0)
    }

    // MARK: - Single Day

    func testSolvedToday_returnsOne() {
        let dates = [today]
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: today), 1)
    }

    func testSolvedYesterday_returnsOne() {
        let dates = [daysAgo(1)]
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: today), 1)
    }

    func testSolvedTwoDaysAgo_returnsZero() {
        let dates = [daysAgo(2)]
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: today), 0)
    }

    // MARK: - Consecutive Days

    func testThreeConsecutiveDaysEndingToday() {
        let dates = [today, daysAgo(1), daysAgo(2)]
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: today), 3)
    }

    func testThreeConsecutiveDaysEndingYesterday() {
        let dates = [daysAgo(1), daysAgo(2), daysAgo(3)]
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: today), 3)
    }

    func testSevenDayStreak() {
        let dates = (0..<7).map { daysAgo($0) }
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: today), 7)
    }

    // MARK: - Gap in Streak

    func testGapBreaksStreak() {
        // Today, yesterday, then skip a day, then 3 days ago
        let dates = [today, daysAgo(1), daysAgo(3)]
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: today), 2)
    }

    func testGapAfterYesterday() {
        // Yesterday, then skip a day, then 3 days ago
        let dates = [daysAgo(1), daysAgo(3), daysAgo(4)]
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: today), 1)
    }

    // MARK: - Duplicate Dates (multiple solves same day)

    func testMultipleSolvesOnSameDay_countAsOne() {
        let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!
        let evening = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: today)!
        let dates = [morning, evening]
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: today), 1)
    }

    func testMultipleSolvesAcrossConsecutiveDays() {
        let todayMorning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!
        let todayEvening = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: today)!
        let yesterdayMorning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: daysAgo(1))!
        let dates = [todayMorning, todayEvening, yesterdayMorning]
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: today), 2)
    }

    // MARK: - Unordered Input

    func testUnorderedDates_stillCalculatesCorrectly() {
        let dates = [daysAgo(2), today, daysAgo(1)]
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: today), 3)
    }

    // MARK: - Long Streak

    func testThirtyDayStreak() {
        let dates = (0..<30).map { daysAgo($0) }
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: today), 30)
    }

    func testHundredDayStreak() {
        let dates = (0..<100).map { daysAgo($0) }
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: today), 100)
    }

    // MARK: - Old Activity Only

    func testOnlyOldDates_returnsZero() {
        let dates = [daysAgo(10), daysAgo(11), daysAgo(12)]
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: today), 0)
    }

    // MARK: - Reference Date Injection

    func testCustomReferenceDate() {
        let refDate = daysAgo(5)
        // Activity on refDate, refDate-1, refDate-2
        let dates = [daysAgo(5), daysAgo(6), daysAgo(7)]
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: refDate), 3)
    }

    // MARK: - Edge: Midnight Boundary

    func testSolvedJustBeforeMidnight() {
        let lateYesterday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: daysAgo(1))!
        let dates = [lateYesterday]
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: today), 1)
    }

    func testSolvedAtMidnightToday() {
        let midnightToday = calendar.startOfDay(for: today)
        let dates = [midnightToday]
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: today), 1)
    }

    // MARK: - Streak With Scattered Old Data

    func testStreakIgnoresOldNonConsecutiveData() {
        // Current streak of 3, plus some old scattered dates
        let dates = [today, daysAgo(1), daysAgo(2), daysAgo(10), daysAgo(20)]
        XCTAssertEqual(StreakCalculator.calculateStreak(from: dates, referenceDate: today), 3)
    }
}
