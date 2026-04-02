import SwiftUI

struct MilestoneCelebrationView: View {
    let message: String
    @Binding var isPresented: Bool
    @State private var showConfetti = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Celebration card
            VStack(spacing: AppSpacing.xl) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(AppColor.xpGold)

                Text("Milestone!")
                    .font(AppFont.largeTitle)

                Text(message)
                    .font(AppFont.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    dismiss()
                } label: {
                    Text("Continue")
                        .font(AppFont.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.xxxl)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColor.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.scalePress)
            }
            .padding(AppSpacing.xxxl)
            .background(AppColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
            .elevatedShadow()
            .scaleEffect(scale)
            .opacity(opacity)
            .padding(AppSpacing.xxl)

            // Confetti
            ConfettiView(isActive: $showConfetti)
                .ignoresSafeArea()
        }
        .onAppear {
            HapticManager.shared.success()
            withAnimation(AppAnimation.springBouncy) {
                scale = 1.0
                opacity = 1.0
            }
            showConfetti = true
        }
    }

    private func dismiss() {
        withAnimation(AppAnimation.fadeQuick) {
            opacity = 0
            scale = 0.9
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
        }
    }
}
