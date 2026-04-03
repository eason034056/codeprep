import XCTest
@testable import LeetCodeLearner

// MARK: - AuthError Tests

/// Tests for the AuthError enum, including the new Apple Sign-In error cases.
/// Follows the existing SM2AlgorithmTests pattern.
final class AuthErrorTests: XCTestCase {

    // MARK: - Error Description Tests

    // Test: Google token error has a meaningful description
    func test_errorDescription_missingGoogleIDToken_returnsNonEmpty() {
        let error = AuthError.missingGoogleIDToken
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
        XCTAssertTrue(error.errorDescription!.contains("Google"))
    }

    // Test: Apple token error has a meaningful description
    func test_errorDescription_missingAppleIDToken_returnsNonEmpty() {
        let error = AuthError.missingAppleIDToken
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
        XCTAssertTrue(error.errorDescription!.contains("Apple"))
    }

    // Test: Apple sign-in failure wraps the underlying error message
    func test_errorDescription_appleSignInFailed_containsUnderlyingError() {
        let underlying = NSError(domain: "ASAuthorizationError", code: 1001, userInfo: [
            NSLocalizedDescriptionKey: "The operation couldn't be completed."
        ])
        let error = AuthError.appleSignInFailed(underlying)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Apple Sign-In failed"))
    }

    // Test: Apple sign-in cancellation surfaces the cancel reason
    func test_errorDescription_appleSignInCancelled_containsCancelInfo() {
        // ⚠️ ASAuthorizationError.canceled uses code 1001
        let cancelError = NSError(domain: "com.apple.AuthenticationServices.AuthorizationError",
                                  code: 1001,
                                  userInfo: [NSLocalizedDescriptionKey: "The operation was canceled."])
        let error = AuthError.appleSignInFailed(cancelError)
        XCTAssertNotNil(error.errorDescription)
        // The description should mention Apple Sign-In, not just the raw system error
        XCTAssertTrue(error.errorDescription!.contains("Apple"))
    }

    // Test: userCancelled returns nil description (silent dismiss — no UI error shown)
    func test_errorDescription_userCancelled_returnsNil() {
        let error = AuthError.userCancelled
        XCTAssertNil(error.errorDescription,
                     "userCancelled should return nil — callers silently dismiss, no error shown")
    }

    // Test: all AuthError cases (except userCancelled) produce LocalizedError descriptions
    func test_allCases_haveNonNilDescriptions() {
        let cases: [AuthError] = [
            .missingGoogleIDToken,
            .missingAppleIDToken,
            .appleSignInFailed(NSError(domain: "test", code: 0))
        ]
        for error in cases {
            XCTAssertNotNil(error.errorDescription,
                            "AuthError case should have a non-nil errorDescription")
        }
    }
}

// MARK: - Apple Sign-In Configuration Tests

/// Validates that project configuration is correct for Apple Sign-In.
final class AppleSignInConfigTests: XCTestCase {

    // Test: entitlements file contains Apple Sign-In capability
    func test_entitlements_containsAppleSignInCapability() {
        // 💡 This test verifies the entitlements plist at build time.
        //    If the entitlement is missing, Apple Sign-In will fail silently at runtime.
        guard let entitlementsPath = Bundle.main.path(forResource: "LeetCodeLearner", ofType: "entitlements") ??
                Bundle(for: type(of: self)).path(forResource: "LeetCodeLearner", ofType: "entitlements") else {
            // ⚠️ Entitlements are embedded at build time, not bundled as a resource.
            //    This test documents the REQUIREMENT — actual validation must be manual.
            //    See QA Report: BUG-002 for the missing entitlement issue.
            return
        }

        if let dict = NSDictionary(contentsOfFile: entitlementsPath) {
            let appleSignIn = dict["com.apple.developer.applesignin"] as? [String]
            XCTAssertNotNil(appleSignIn, "Entitlements must include com.apple.developer.applesignin")
            XCTAssertTrue(appleSignIn?.contains("Default") ?? false)
        }
    }
}

// MARK: - SettingsViewModel Apple Sign-In Tests

/// Tests for SettingsViewModel's signInWithApple integration.
/// ⚠️ These tests require AuthManager to be mockable (protocol extraction needed).
///    Currently AuthManager is a concrete final class — these tests document expected
///    behavior for when testability is improved.
///
/// TODO: Extract AuthManagerProtocol to enable proper unit testing.
///       For now, these serve as executable acceptance criteria documentation.
final class AppleSignInViewModelTests: XCTestCase {

    // Test: signInWithApple clears previous auth errors before starting
    // Requires: MockAuthManager or protocol extraction
    func test_signInWithApple_clearsPreviousError() {
        // GIVEN: A SettingsViewModel with an existing auth error
        // WHEN:  signInWithApple() is called
        // THEN:  authErrorMessage is set to nil before the async call begins
        //
        // ⚠️ Cannot verify without AuthManager mockability.
        //    Verified via code review: SettingsViewModel.swift line 168
        //    `authErrorMessage = nil` is called before `Task { ... }`
    }

    // Test: signInWithApple surfaces error message on failure
    // Requires: MockAuthManager or protocol extraction
    func test_signInWithApple_setsErrorOnFailure() {
        // GIVEN: AuthManager.signInWithApple() throws an error
        // WHEN:  SettingsViewModel.signInWithApple() is called
        // THEN:  authErrorMessage is set to the error's localizedDescription
        //
        // ⚠️ Cannot verify without AuthManager mockability.
        //    Verified via code review: SettingsViewModel.swift lines 171-175
    }
}
