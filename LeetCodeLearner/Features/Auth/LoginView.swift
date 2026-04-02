import SwiftUI
import GoogleSignInSwift

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var errorMessage: String?
    @State private var isSigningIn = false

    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

            VStack(spacing: AppSpacing.xxxl) {
                Spacer()

                // App branding
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(AppColor.accentGradient)

                    Text("CodePrep")
                        .font(AppFont.largeTitle)
                        .foregroundStyle(.white)

                    Text("Master algorithms with\nAI-guided practice")
                        .font(AppFont.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Sign in section
                VStack(spacing: AppSpacing.lg) {
                    Button(action: signIn) {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 20))
                            Text(isSigningIn ? "Signing in..." : "Continue with Google")
                                .font(AppFont.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.lg)
                        .background(AppColor.accentGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                        .cardShadow()
                    }
                    .disabled(isSigningIn)
                    .opacity(isSigningIn ? 0.7 : 1)
                    .padding(.horizontal, AppSpacing.xxxl)

                    if let error = errorMessage {
                        Text(error)
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.xl)
                    }
                }

                Spacer()
                    .frame(height: 60)
            }
        }
    }

    private func signIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to present sign-in"
            return
        }

        isSigningIn = true
        errorMessage = nil

        Task {
            do {
                try await authManager.signInWithGoogle(presenting: rootVC)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSigningIn = false
        }
    }
}
