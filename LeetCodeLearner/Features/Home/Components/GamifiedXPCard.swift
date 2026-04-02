import SwiftUI

struct GamifiedXPCard: View {
    let xp: Int
    @State private var displayXP: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(AppColor.xpGold)
                    .symbolEffect(.pulse, options: .repeating.speed(0.3), value: xp > 0)

                Spacer()
            }

            Text("\(displayXP)")
                .font(AppFont.title)
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text("Total XP")
                .font(AppFont.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(
            ZStack {
                AppColor.cardBackground
                AppColor.xpGradient.opacity(0.12)
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
                displayXP = xp
            }
        }
        .onChange(of: xp) { _, newValue in
            withAnimation(AppAnimation.countUp) {
                displayXP = newValue
            }
        }
    }
}
