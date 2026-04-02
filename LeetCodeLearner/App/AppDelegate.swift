import Foundation
import UIKit
import UserNotifications
import GoogleSignIn
import FirebaseCore

final class AppDelegate: NSObject, UIApplicationDelegate {
    let notificationManager = NotificationManager()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Firebase (must be first)
        FirebaseApp.configure()

        // Configure Google Sign-In using the Firebase-provided client ID
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        UNUserNotificationCenter.current().delegate = notificationManager
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
