import SwiftUI

struct ContentView: View {
    @EnvironmentObject var container: DIContainer
    @State private var selectedTab = 0
    @State private var homePath = NavigationPath()
    @State private var reviewPath = NavigationPath()
    @Namespace private var tabNamespace

    private var isInChat: Bool {
        !homePath.isEmpty || !reviewPath.isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // Today tab — needs NavigationStack for ChatView navigation
                NavigationStack(path: $homePath) {
                    HomeView(
                        viewModel: container.homeViewModel,
                        onReviewTap: {
                            withAnimation(AppAnimation.springDefault) {
                                selectedTab = 2
                            }
                        }
                    )
                    .navigationDestination(for: Problem.self) { problem in
                        ChatView(viewModel: container.makeChatViewModel(for: problem))
                    }
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(0)

                // Learn tab
                LearningPathsView(viewModel: container.makeLearningPathsViewModel())
                    .toolbar(.hidden, for: .tabBar)
                    .tag(1)

                // Review tab — needs NavigationStack for ChatView navigation
                NavigationStack(path: $reviewPath) {
                    ReviewQueueView(
                        viewModel: container.makeReviewQueueViewModel()
                    )
                    .navigationDestination(for: Problem.self) { problem in
                        ChatView(viewModel: container.makeChatViewModel(for: problem))
                    }
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(2)

                // Settings tab
                SettingsView(viewModel: container.makeSettingsViewModel())
                    .toolbar(.hidden, for: .tabBar)
                    .tag(3)
            }

            // Custom tab bar — hidden when navigated into a chat
            if !isInChat {
                CustomTabBarView(selectedTab: $selectedTab, namespace: tabNamespace)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isInChat)
        .onReceive(NotificationCenter.default.publisher(for: .openProblemFromNotification)) { notification in
            if let identifier = notification.userInfo?["identifier"] as? String {
                handleNotificationDeepLink(identifier)
            }
        }
        .task {
            await requestNotificationPermission()
        }
    }

    private func requestNotificationPermission() async {
        let manager = container.notificationManager
        let granted = await manager.requestAuthorization()
        if granted {
            await scheduleNotifications()
        }
    }

    private func scheduleNotifications() async {
        let settingsVM = container.makeSettingsViewModel()
        let times = [
            settingsVM.notificationTime1,
            settingsVM.notificationTime2,
            settingsVM.notificationTime3
        ]

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var dailyChallenges: [DailyChallengeEntry] = []
        var excludedIds: Set<Int> = []
        for dayOffset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: today)!
            let challenge = container.selectDailyProblems.execute(
                learningPath: container.selectedLearningPath,
                date: date,
                excluding: excludedIds
            )
            excludedIds.formUnion(challenge.problemIds)
            let problems = container.problemRepo.fetchByIds(challenge.problemIds)
            dailyChallenges.append(DailyChallengeEntry(
                date: date,
                problems: problems,
                pendingCount: challenge.remainingCount
            ))
        }

        await container.scheduleNotifications.execute(
            times: times,
            dailyChallenges: dailyChallenges
        )
    }

    private func handleNotificationDeepLink(_ identifier: String) {
        // Extract problem index from identifier (e.g., "daily-problem-0")
        selectedTab = 0
        // The HomeView will show today's problems
    }
}
