import Foundation

enum StreakCalculator {

    /// Calculates the current streak from an array of completion dates.
    /// - Parameters:
    ///   - dates: Dates when problems were solved.
    ///   - referenceDate: The "today" date (defaults to now; injectable for testing).
    /// - Returns: Number of consecutive days with at least one completion, counting back from today/yesterday.
    static func calculateStreak(from dates: [Date], referenceDate: Date = Date()) -> Int {
        guard !dates.isEmpty else { return 0 }

        let calendar = Calendar.current
        let uniqueDays = Set(dates.map { calendar.startOfDay(for: $0) })
        let sortedDays = uniqueDays.sorted(by: >)

        let today = calendar.startOfDay(for: referenceDate)
        guard let mostRecent = sortedDays.first,
              calendar.isDate(mostRecent, inSameDayAs: today) || calendar.isDate(mostRecent, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: today)!) else {
            return 0
        }

        var streak = 0
        var checkDate = calendar.isDate(mostRecent, inSameDayAs: today) ? today : calendar.date(byAdding: .day, value: -1, to: today)!

        for day in sortedDays {
            if calendar.isDate(day, inSameDayAs: checkDate) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else if day < checkDate {
                break
            }
        }

        return streak
    }
}
