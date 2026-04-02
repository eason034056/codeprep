import SwiftUI

struct LevelHeaderView: View {
    let level: PlayerLevel
    let totalXP: Int
    let progress: Double

    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Level badge
            Text("Level \(level.level)")
                .font(AppFont.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(AppColor.accent.opacity(0.3))
                .clipShape(Capsule())

            // Level title
            Text(level.title)
                .font(AppFont.title)
                .foregroundStyle(.white)

            // XP progress bar
            VStack(spacing: AppSpacing.xs) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColor.accentGradient)
                            .frame(width: geo.size.width * animatedProgress)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(totalXP) XP")
                        .font(AppFont.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    if level.xpCeiling != Int.max {
                        Text("\(level.xpCeiling) XP to Level \(level.level + 1)")
                            .font(AppFont.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        Text("Max Level")
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.xpGold)
                    }
                }
            }
        }
        .padding(AppSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(
                    LinearGradient(
                        colors: AppColor.levelGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .onAppear {
            let anim = reduceMotion ? .easeOut(duration: 0.15) : AppAnimation.progressDraw
            withAnimation(anim) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(AppAnimation.progressDraw) {
                animatedProgress = newValue
            }
        }
    }
}
