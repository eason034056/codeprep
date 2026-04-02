import SwiftUI

struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Cat tutor avatar
            Image(systemName: "cat.fill")
                .font(.system(size: 18))
                .foregroundStyle(AppColor.accent)
                .frame(width: 28, height: 28)

            HStack(spacing: AppSpacing.xs) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(AppColor.accent.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)

            Spacer()
        }
        .onAppear { animating = true }
    }
}
