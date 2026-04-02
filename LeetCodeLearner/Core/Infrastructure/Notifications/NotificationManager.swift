import Foundation
import UserNotifications

protocol NotificationScheduling: Sendable {
    func scheduleOneTimeNotification(
        identifier: String,
        title: String,
        body: String,
        dateComponents: DateComponents,
        badge: Int,
        categoryIdentifier: String
    ) async
    func removeAllPending() async
}

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate, Sendable, NotificationScheduling {

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert]
            let granted = try await center.requestAuthorization(options: options)
            if granted {
                await registerCategories()
            }
            return granted
        } catch {
            // Fallback: try without critical alerts
            do {
                let options: UNAuthorizationOptions = [.alert, .sound, .badge]
                return try await center.requestAuthorization(options: options)
            } catch {
                return false
            }
        }
    }

    func scheduleOneTimeNotification(
        identifier: String,
        title: String,
        body: String,
        dateComponents: DateComponents,
        badge: Int,
        categoryIdentifier: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.badge = NSNumber(value: badge)
        content.categoryIdentifier = categoryIdentifier
        content.interruptionLevel = .timeSensitive

        // Try critical alert sound first, fallback to default
        if await hasCriticalAlertPermission() {
            content.sound = UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
        } else {
            content.sound = .default
        }

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    func removeAllPending() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func updateBadge(_ count: Int) async {
        try? await UNUserNotificationCenter.current().setBadgeCount(count)
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let identifier = response.notification.request.identifier
        if response.actionIdentifier == "START_PROBLEM" || response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // Post notification for deep linking
            NotificationCenter.default.post(
                name: .openProblemFromNotification,
                object: nil,
                userInfo: ["identifier": identifier]
            )
        }
    }

    // MARK: - Private

    private func registerCategories() async {
        let startAction = UNNotificationAction(
            identifier: "START_PROBLEM",
            title: "Start Problem",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: "DAILY_PROBLEM",
            actions: [startAction],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private func hasCriticalAlertPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.criticalAlertSetting == .enabled
    }
}

extension Notification.Name {
    static let openProblemFromNotification = Notification.Name("openProblemFromNotification")
}
