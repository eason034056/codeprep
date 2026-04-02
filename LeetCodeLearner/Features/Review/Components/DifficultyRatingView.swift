import SwiftUI

struct DifficultyRatingView: View {
    let onRate: (Int) -> Void

    private let ratings: [(Int, String, Color)] = [
        (0, "Blackout", AppColor.error),
        (1, "Wrong", AppColor.error.opacity(0.7)),
        (2, "Hard", AppColor.warning),
        (3, "Difficult", AppColor.xpGold),
        (4, "Good", AppColor.success.opacity(0.7)),
        (5, "Perfect", AppColor.success)
    ]

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(ratings, id: \.0) { rating, label, color in
                Button {
                    HapticManager.shared.light()
                    onRate(rating)
                } label: {
                    VStack(spacing: AppSpacing.xs) {
                        Text("\(rating)")
                            .font(AppFont.title3)
                            .fontWeight(.bold)
                        Text(label)
                            .font(AppFont.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                    .background(color.opacity(0.15))
                    .foregroundStyle(color)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                }
                .buttonStyle(.scalePress)
                .accessibilityLabel("Rate \(rating), \(label)")
            }
        }
        .accessibilityLabel("Recall quality rating")
    }
}
