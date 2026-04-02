import SwiftUI

struct RootView: View {
    @EnvironmentObject var container: DIContainer
    @EnvironmentObject var authManager: AuthManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView {
                        withAnimation {
                            hasCompletedOnboarding = true
                        }
                    }
                } else {
                    ContentView()
                }
            }
            .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .splashDidFinish)) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                showSplash = false
            }
        }
        .task {
            // Safety timeout in case video fails to trigger notification
            try? await Task.sleep(for: .seconds(3))
            if showSplash {
                withAnimation(.easeOut(duration: 0.3)) {
                    showSplash = false
                }
            }
        }
        .task {
            if hasCompletedOnboarding {
                await authManager.restorePreviousSignIn()
            }
        }
    }
}
