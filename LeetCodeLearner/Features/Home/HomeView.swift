import SwiftUI

struct HomeView: View {
    @EnvironmentObject var container: DIContainer
    @ObservedObject var viewModel: HomeViewModel
    let onReviewTap: () -> Void

    @State private var animatedLevelProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Animated background
            AppColor.pageBackground
                .ignoresSafeArea()
            AnimatedMeshBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Greeting
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(viewModel.greeting)
                            .font(AppFont.title3)
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Ready to solve?")
                            .font(AppFont.largeTitle)
                            .foregroundStyle(AppColor.accentGradient)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    .staggeredAppearance(index: 0)

                    // Streak & XP row
                    HStack(spacing: AppSpacing.md) {
                        GamifiedStreakCard(streak: viewModel.currentStreak)
                        GamifiedXPCard(xp: viewModel.totalXP)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Streak: \(viewModel.currentStreak) days, XP: \(viewModel.totalXP)")
                    .staggeredAppearance(index: 1)

                    // Progress card
                    progressCard
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Level \(viewModel.playerLevel.level), \(viewModel.overallSolved) of \(viewModel.overallTotal) problems solved")
                        .staggeredAppearance(index: 2)

                    // Due reviews
                    if viewModel.dueReviewCount > 0 {
                        reviewReminderCard
                            .staggeredAppearance(index: 3)
                    }

                    // Today's Quest
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundStyle(AppColor.accent)
                            Text("Today's Quest")
                                .font(AppFont.title2)
                        }

                        if viewModel.dailyProblems.isEmpty {
                            VStack(spacing: AppSpacing.md) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 40))
                                    .foregroundStyle(AppColor.success)
                                Text("All caught up!")
                                    .font(AppFont.headline)
                                Text("Check back tomorrow for new problems.")
                                    .font(AppFont.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.xxl)
                        } else {
                            ForEach(Array(viewModel.dailyProblems.enumerated()), id: \.element.id) { index, problem in
                                NavigationLink(value: problem) {
                                    ProblemCardView(
                                        problem: problem,
                                        isCompleted: viewModel.isProblemCompleted(problem.id),
                                        xpReward: viewModel.xpReward(for: problem.difficulty),
                                        showDifficultyAccent: true
                                    )
                                }
                                .accessibilityLabel("Problem \(problem.id), \(problem.title), \(problem.difficulty.rawValue)")
                                .buttonStyle(.scalePress)
                                .staggeredAppearance(index: index + 4)
                            }
                        }
                    }
                }
                .padding(AppSpacing.lg)
                .padding(.bottom, 80)
            }

            // Milestone celebration overlay
            if viewModel.showMilestoneCelebration {
                MilestoneCelebrationView(
                    message: viewModel.milestoneMessage,
                    isPresented: $viewModel.showMilestoneCelebration
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.loadDailyProblems()
            let anim = reduceMotion ? .easeOut(duration: 0.15) : AppAnimation.progressDraw
            withAnimation(anim) {
                animatedLevelProgress = viewModel.levelProgress
            }
        }
        .onChange(of: viewModel.levelProgress) { _, newValue in
            withAnimation(AppAnimation.progressDraw) {
                animatedLevelProgress = newValue
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProgressUpdated"))) { _ in
            viewModel.loadDailyProblems()
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(spacing: AppSpacing.md) {
            // Level & XP bar
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("Level \(viewModel.playerLevel.level) · \(viewModel.playerLevel.title)")
                        .font(AppFont.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(viewModel.totalXP) XP")
                        .font(AppFont.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColor.accentGradient)
                            .frame(width: geo.size.width * animatedLevelProgress)
                    }
                }
                .frame(height: 6)
            }

            Divider().background(Color.white.opacity(0.06))

            // Problems solved
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("\(viewModel.overallSolved)/\(viewModel.overallTotal)")
                        .font(AppFont.title)
                    Text("Problems Solved")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)

                    if viewModel.xpToNextLevel > 0 {
                        Text("\(viewModel.xpToNextLevel) XP to next level")
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.accent.opacity(0.8))
                            .padding(.top, AppSpacing.xxs)
                    }
                }
                Spacer()
                CircularProgressView(
                    progress: viewModel.overallTotal > 0
                        ? Double(viewModel.overallSolved) / Double(viewModel.overallTotal)
                        : 0,
                    lineWidth: 10
                )
                .frame(width: 90, height: 90)
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .stroke(AppColor.cardBorder)
        )
        .softShadow()
    }

    // MARK: - Review Reminder

    private var reviewReminderCard: some View {
        Button(action: {
            HapticManager.shared.light()
            onReviewTap()
        }) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(AppColor.warning)
                VStack(alignment: .leading) {
                    Text("\(viewModel.dueReviewCount) reviews due")
                        .font(AppFont.headline)
                    Text("Practice spaced repetition")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(AppSpacing.lg)
            .background(AppColor.warning.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(AppColor.cardBorder)
            )
            .softShadow()
        }
        .buttonStyle(.scalePress)
        .accessibilityLabel("\(viewModel.dueReviewCount) reviews due. Tap to start reviewing.")
    }
}
