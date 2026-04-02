import SwiftUI

@main
struct LeetCodeLearnerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var container = DIContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(container.authManager)
                .preferredColorScheme(.dark)
        }
    }
}
