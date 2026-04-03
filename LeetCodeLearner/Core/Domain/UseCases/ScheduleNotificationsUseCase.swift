import Foundation

struct DailyChallengeEntry {
    let date: Date
    let problems: [Problem]
    let pendingCount: Int
}

final class ScheduleNotificationsUseCase {
    private let notificationManager: NotificationScheduling

    init(notificationManager: NotificationScheduling) {
        self.notificationManager = notificationManager
    }

    func execute(times: [DateComponents], dailyChallenges: [DailyChallengeEntry]) async {
        await notificationManager.removeAllPending()

        let calendar = Calendar.current

        for (dayOffset, challenge) in dailyChallenges.enumerated() {
            for (slotIndex, time) in times.prefix(3).enumerated() {
                let problem = slotIndex < challenge.problems.count ? challenge.problems[slotIndex] : nil
                let title = "CodeReps Time!"
                let body: String
                if let problem = problem {
                    body = "\(problem.title) (\(problem.difficulty.rawValue)) - \(problem.topic.rawValue)"
                } else {
                    body = "You have problems waiting for you!"
                }

                var dateComponents = calendar.dateComponents([.year, .month, .day], from: challenge.date)
                dateComponents.hour = time.hour
                dateComponents.minute = time.minute

                await notificationManager.scheduleOneTimeNotification(
                    identifier: "daily-d\(dayOffset)-s\(slotIndex)",
                    title: title,
                    body: body,
                    dateComponents: dateComponents,
                    badge: challenge.pendingCount,
                    categoryIdentifier: "DAILY_PROBLEM"
                )
            }
        }
    }
}
