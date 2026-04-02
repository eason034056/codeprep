import SwiftUI

struct GamifiedStreakCard: View {
    let streak: Int
    @State private var displayStreak: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(AppColor.streakFlame)
                    .symbolEffect(.bounce, options: .repeating.speed(0.5), value: streak > 0)

                Spacer()
            }

            Text("\(displayStreak)")
                .font(AppFont.title)
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text("Day Streak")
                .font(AppFont.caption)
                .foregroundStyle(.white.opacity(0.6))

            if streak > 3 {
                Text("ON FIRE!")
                    .font(AppFont.caption)
                    .fontWeight(.black)
                    .foregroundStyle(AppColor.streakFlame)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(
            ZStack {
                AppColor.cardBackground
                AppColor.streakGradient.opacity(0.15)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .stroke(AppColor.cardBorder)
        )
        .softShadow()
        .onAppear {
            withAnimation(AppAnimation.countUp) {
                displayStreak = streak
            }
        }
        .onChange(of: streak) { _, newValue in
            withAnimation(AppAnimation.countUp) {
                displayStreak = newValue
            }
        }
    }
}
