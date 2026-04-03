import SwiftUI
import GoogleSignInSwift
import AuthenticationServices

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

                    Text("CodeReps")
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
                    Button(action: signInGoogle) {
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

                    // 💡 "or" divider — visually separates the two auth options
                    HStack(spacing: AppSpacing.md) {
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 1)
                        Text("or")
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, AppSpacing.xxxl)

                    // 💡 SignInWithAppleButton — Apple HIG mandates this native button
                    //    for apps that offer third-party sign-in (App Store Guideline 4.8).
                    //    onRequest sets the nonce; onCompletion completes the Firebase flow.
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                        // 💡 prepareAppleSignIn() generates a nonce, stores it, and returns its SHA256 hash.
                        //    Firebase will verify this hash matches the raw nonce during credential creation.
                        request.nonce = authManager.prepareAppleSignIn()
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                                errorMessage = "Failed to obtain Apple ID credential."
                                return
                            }
                            isSigningIn = true
                            errorMessage = nil
                            Task {
                                do {
                                    try await authManager.completeAppleSignIn(credential: credential)
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                                isSigningIn = false
                            }
                        case .failure(let error):
                            // ⚠️ User tapping Cancel triggers ASAuthorizationError.canceled —
                            //    this is normal behavior, not an error to display.
                            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                                return
                            }
                            errorMessage = error.localizedDescription
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                    .padding(.horizontal, AppSpacing.xxxl)
                    .disabled(isSigningIn)
                    .opacity(isSigningIn ? 0.7 : 1)

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

    private func signInGoogle() {
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
