import Foundation
@testable import LeetCodeLearner

final class MockNotificationScheduler: NotificationScheduling, @unchecked Sendable {

    struct ScheduledNotification {
        let identifier: String
        let title: String
        let body: String
        let dateComponents: DateComponents
        let badge: Int
        let categoryIdentifier: String
    }

    var scheduledNotifications: [ScheduledNotification] = []
    var removeAllPendingCallCount = 0

    func scheduleOneTimeNotification(
        identifier: String,
        title: String,
        body: String,
        dateComponents: DateComponents,
        badge: Int,
        categoryIdentifier: String
    ) async {
        scheduledNotifications.append(ScheduledNotification(
            identifier: identifier,
            title: title,
            body: body,
            dateComponents: dateComponents,
            badge: badge,
            categoryIdentifier: categoryIdentifier
        ))
    }

    func removeAllPending() async {
        removeAllPendingCallCount += 1
    }
}
