import Foundation
import FirebaseAuth
import GoogleSignIn

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

    var errorDescription: String? {
        switch self {
        case .missingGoogleIDToken:
            return "Failed to obtain Google ID token."
        }
    }
}
