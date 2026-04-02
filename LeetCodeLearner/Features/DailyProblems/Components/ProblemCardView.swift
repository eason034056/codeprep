import SwiftUI

struct ProblemCardView: View {
    let problem: Problem
    var isCompleted: Bool = false
    var xpReward: Int? = nil
    var showDifficultyAccent: Bool = false
    @State private var showCheck = false

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Difficulty accent bar
            if showDifficultyAccent {
                RoundedRectangle(cornerRadius: 2)
                    .fill(problem.difficulty.color)
                    .frame(width: 3)
            }

            // Status icon / number badge
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppColor.success)
                    .shadow(color: AppColor.success.opacity(0.6), radius: 6)
                    .scaleEffect(showCheck ? 1.0 : 0.8)
            } else {
                Text("\(problem.id)")
                    .font(AppFont.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(problem.difficulty.color)
                    .frame(width: 28, height: 28)
                    .background(problem.difficulty.color.opacity(0.15))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(problem.title)
                    .font(AppFont.body)
                    .fontWeight(.medium)
                    .strikethrough(isCompleted, color: .secondary)
                    .lineLimit(1)

                HStack(spacing: AppSpacing.sm) {
                    DifficultyBadge(difficulty: problem.difficulty)

                    Text(problem.topic.rawValue)
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // XP reward badge
            if let xp = xpReward, !isCompleted {
                Text("+\(xp)")
                    .font(AppFont.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColor.xpGold)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xxs)
                    .background(AppColor.xpGold.opacity(0.15))
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(AppSpacing.lg)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColor.cardBorder)
        )
        .softShadow()
        .onAppear {
            if isCompleted {
                withAnimation(AppAnimation.springBouncy.delay(0.2)) {
                    showCheck = true
                }
            }
        }
    }
}
