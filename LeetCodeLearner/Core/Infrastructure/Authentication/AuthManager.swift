import Foundation
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

struct AuthenticatedUser: Sendable {
    let userId: String          // Firebase UID
    let email: String
    let displayName: String?
    let profileImageURL: URL?
}

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var currentUser: AuthenticatedUser?
    @Published private(set) var isLoading: Bool = true

    var isAuthenticated: Bool { currentUser != nil }
    var userId: String? { currentUser?.userId }

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    // 💡 Nonce is stored between request creation and callback completion —
    //    Firebase uses it to verify the Apple credential wasn't replayed.
    private var currentNonce: String?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                guard let self else { return }
                if let firebaseUser {
                    self.currentUser = self.mapFirebaseUser(firebaseUser)
                } else {
                    self.currentUser = nil
                }
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Restore Session

    func restorePreviousSignIn() async {
        isLoading = true
        try? await Task.sleep(for: .milliseconds(500))
        isLoading = false
    }

    // MARK: - Google Sign-In

    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingGoogleIDToken
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        try await Auth.auth().signIn(with: credential)
    }

    // MARK: - Apple Sign-In (Native SignInWithAppleButton path)

    // 💡 Two-step flow for SwiftUI's SignInWithAppleButton:
    //    1. onRequest  → call prepareAppleSignIn() to get the hashed nonce
    //    2. onCompletion → call completeAppleSignIn(credential:) with the result

    /// Generates a fresh nonce, stores it, and returns its SHA256 hash
    /// for the `onRequest` handler of `SignInWithAppleButton`.
    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    /// Completes Apple Sign-In using the credential from `SignInWithAppleButton`'s `onCompletion`.
    /// - Parameter credential: The Apple ID credential from a successful authorization.
    func completeAppleSignIn(credential: ASAuthorizationAppleIDCredential) async throws {
        // ⚠️ currentNonce must exist — it was set by prepareAppleSignIn() in onRequest.
        guard let nonce = currentNonce else {
            throw AuthError.missingAppleIDToken
        }
        defer { currentNonce = nil }

        guard let idTokenData = credential.identityToken,
              let idToken = String(data: idTokenData, encoding: .utf8) else {
            throw AuthError.missingAppleIDToken
        }

        let firebaseCredential = OAuthProvider.credential(
            providerID: .apple,
            idToken: idToken,
            rawNonce: nonce
        )
        try await Auth.auth().signIn(with: firebaseCredential)
    }

    // MARK: - Apple Sign-In (ASAuthorizationController path — used by custom buttons)

    /// Full Apple Sign-In flow via ASAuthorizationController + delegate.
    /// Used when a custom button triggers sign-in (e.g., SettingsView).
    func signInWithApple() async throws {
        let nonce = randomNonceString()
        currentNonce = nonce
        // 💡 defer ensures cleanup even if the continuation throws or the flow is cancelled.
        defer {
            _appleSignInDelegate = nil
            currentNonce = nil
        }

        let appleCredential: ASAuthorizationAppleIDCredential = try await withCheckedThrowingContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            // ⚠️ Firebase requires the raw nonce's SHA256 hash in the request,
            //    but the raw nonce itself when creating the Firebase credential.
            request.nonce = sha256(nonce)

            let delegate = AppleSignInDelegate(continuation: continuation)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate
            // 💡 presentationContextProvider tells iOS which window to anchor the sheet to.
            //    Without it, behavior is undocumented on iOS 17+ and breaks in multi-scene apps.
            controller.presentationContextProvider = self
            self._appleSignInDelegate = delegate
            controller.performRequests()
        }

        guard let idTokenData = appleCredential.identityToken,
              let idToken = String(data: idTokenData, encoding: .utf8) else {
            throw AuthError.missingAppleIDToken
        }

        let credential = OAuthProvider.credential(
            providerID: .apple,
            idToken: idToken,
            rawNonce: nonce
        )
        try await Auth.auth().signIn(with: credential)
    }

    // Prevent delegate deallocation during async Apple callback
    private var _appleSignInDelegate: AppleSignInDelegate?

    // MARK: - Sign Out

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        try? Auth.auth().signOut()
    }

    // MARK: - Helpers

    private func mapFirebaseUser(_ user: FirebaseAuth.User) -> AuthenticatedUser {
        AuthenticatedUser(
            userId: user.uid,
            email: user.email ?? "",
            displayName: user.displayName,
            profileImageURL: user.photoURL
        )
    }
}

enum AuthError: LocalizedError {
    case missingGoogleIDToken
    case appleSignInFailed(Error)
    case missingAppleIDToken
    // 💡 Thrown when user taps Cancel on the Apple Sign-In sheet.
    //    Callers should silently dismiss — this is not a real error.
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .missingGoogleIDToken:
            return "Failed to obtain Google ID token."
        case .appleSignInFailed(let error):
            return "Apple Sign-In failed: \(error.localizedDescription)"
        case .missingAppleIDToken:
            return "Failed to obtain Apple ID token."
        case .userCancelled:
            return nil
        }
    }
}

// MARK: - Presentation Context (for ASAuthorizationController)

// 💡 Required by ASAuthorizationController to know which window to present the sign-in sheet.
//    Only used by the signInWithApple() path (custom button in SettingsView).
//    SignInWithAppleButton's native flow handles this automatically.
extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            // ⚠️ Fallback: create an empty window. In practice this path shouldn't hit
            //    on a single-scene iOS app, but it satisfies the protocol requirement.
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Nonce Helpers

// 💡 These are private free functions — no reason to expose nonce generation outside this file.

private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    var randomBytes = [UInt8](repeating: 0, count: length)
    let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    // ⚠️ SecRandomCopyBytes can technically fail, but this is extremely rare on iOS.
    if errorCode != errSecSuccess {
        fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
    }
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    return String(randomBytes.map { charset[Int($0) % charset.count] })
}

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    return hashedData.compactMap { String(format: "%02x", $0) }.joined()
}

// MARK: - Apple Sign-In Delegate

/// Bridges ASAuthorizationController delegate callbacks to a Swift continuation.
/// Retained by AuthManager during the sign-in flow to prevent premature deallocation.
private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation?.resume(returning: credential)
        } else {
            continuation?.resume(throwing: AuthError.missingAppleIDToken)
        }
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        // ⚠️ ASAuthorizationError.canceled is normal user behavior (tapped Cancel),
        //    not a real error — surface it as userCancelled so callers can silently dismiss.
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation?.resume(throwing: AuthError.userCancelled)
        } else {
            continuation?.resume(throwing: AuthError.appleSignInFailed(error))
        }
        continuation = nil
    }
}
