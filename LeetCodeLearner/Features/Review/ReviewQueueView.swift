import SwiftUI

struct ReviewQueueView: View {
    @EnvironmentObject var container: DIContainer
    @ObservedObject var viewModel: ReviewQueueViewModel
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // 💡 Weekly schedule card — sits above flashcard flow, hidden when no future cards
                    if viewModel.weeklyTotalCount > 0 {
                        WeeklyScheduleCard(
                            weeklyGroups: viewModel.weeklyGroups,
                            totalCount: viewModel.weeklyTotalCount
                        )
                        .padding(.horizontal, AppSpacing.lg)
                    }

                    // Main review content
                    Group {
                        if viewModel.isComplete {
                            completedView
                        } else if let card = viewModel.currentCard,
                                  let problem = viewModel.problemFor(card: card) {
                            cardReviewView(card: card, problem: problem)
                        } else {
                            emptyView
                        }
                    }
                }
                .padding(.bottom, 80) // Space for custom tab bar
            }
            .scrollIndicators(.hidden)

            // Confetti overlay
            if showConfetti {
                ConfettiView(isActive: $showConfetti)
                    .ignoresSafeArea()
            }
        }
        .navigationTitle("Review")
        .onAppear { viewModel.loadDueCards() }
    }

    private func cardReviewView(card: SpacedRepetitionCard, problem: Problem) -> some View {
        VStack(spacing: AppSpacing.xxl) {
            Spacer()

            // Problem info
            VStack(spacing: AppSpacing.md) {
                Text("#\(problem.id)")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                Text(problem.title)
                    .font(AppFont.title2)
                    .multilineTextAlignment(.center)

                HStack(spacing: AppSpacing.md) {
                    DifficultyBadge(difficulty: problem.difficulty)
                    Text(problem.topic.rawValue)
                        .font(AppFont.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: .infinity)
            .background(AppColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
            .cardShadow()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Problem \(problem.id), \(problem.title), \(problem.difficulty.rawValue), \(problem.topic.rawValue)")

            // Card stats
            HStack(spacing: AppSpacing.xl) {
                statItem(value: "\(card.repetitionCount)", label: "Reviews")
                statItem(value: String(format: "%.1f", card.easinessFactor), label: "EF")
                statItem(value: "\(Int(card.interval))d", label: "Interval")
            }

            // Action buttons
            NavigationLink(value: problem) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "bubble.left.fill")
                    Text("Open Problem Chat")
                }
                .font(AppFont.headline)
                .foregroundStyle(AppColor.accent)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, AppSpacing.md)
                .background(AppColor.accent.opacity(0.1))
                .clipShape(Capsule())
            }
            .accessibilityLabel("Open Problem Chat")
            .buttonStyle(.scalePress)

            Spacer()

            // Rating
            Text("How well did you recall this problem?")
                .font(AppFont.subheadline)
                .foregroundStyle(.secondary)

            DifficultyRatingView { quality in
                HapticManager.shared.medium()
                viewModel.rateCard(quality: quality)
            }

            // Progress
            Text("\(viewModel.currentIndex + 1) of \(viewModel.dueCards.count)")
                .font(AppFont.caption)
                .foregroundStyle(.tertiary)
                .accessibilityLabel("Card \(viewModel.currentIndex + 1) of \(viewModel.dueCards.count)")
        }
        .padding(AppSpacing.lg)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(value)
                .font(AppFont.title3).fontWeight(.bold)
            Text(label)
                .font(AppFont.caption).foregroundStyle(.secondary)
        }
    }

    private var completedView: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppColor.success)
            Text("All Reviews Complete!")
                .font(AppFont.title2)
            Text("Great job! Come back when more cards are due.")
                .font(AppFont.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.lg)
        .onAppear {
            HapticManager.shared.success()
            showConfetti = true
        }
    }

    private var emptyView: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Reviews Due")
                .font(AppFont.title3)

            // 💡 Contextual text: guide user to weekly card when future reviews exist
            if !viewModel.weeklyGroups.isEmpty {
                Text("No reviews due today. Check your upcoming schedule above.")
                    .font(AppFont.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Start solving problems to build your review queue.")
                    .font(AppFont.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppSpacing.lg)
    }
}
