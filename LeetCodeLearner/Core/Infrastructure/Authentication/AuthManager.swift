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

    // MARK: - Apple Sign-In

    func signInWithApple() async throws {
        let nonce = randomNonceString()
        currentNonce = nonce

        // 💡 withCheckedThrowingContinuation bridges the delegate callback to async/await.
        //    AppleSignInDelegate holds the continuation and resumes it once Apple responds.
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
            // 💡 Retain delegate in a class property to prevent deallocation during callback
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
        // 💡 After this call, the auth state listener fires automatically —
        //    no downstream changes needed (same as Google flow).
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

    var errorDescription: String? {
        switch self {
        case .missingGoogleIDToken:
            return "Failed to obtain Google ID token."
        case .appleSignInFailed(let error):
            return "Apple Sign-In failed: \(error.localizedDescription)"
        case .missingAppleIDToken:
            return "Failed to obtain Apple ID token."
        }
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
        continuation?.resume(throwing: AuthError.appleSignInFailed(error))
        continuation = nil
    }
}
