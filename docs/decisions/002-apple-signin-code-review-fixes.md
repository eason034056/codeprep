# Implementation Notes: COD-6 — Apple Sign-In Code Review Fixes

**Date:** 2026-04-02
**Author:** Swift(Senior Engineer)
**Parent Task:** COD-1 (Sign in with Apple)
**Review Source:** COD-4 (Lens code review)

## Problem Statement

Lens's code review on the initial Apple Sign-In implementation (COD-3) identified 2 must-fix issues and 2 improvements:

1. **Overlay hack** on `SignInWithAppleButton` was fragile — taps could trigger both Apple's native flow AND our custom flow simultaneously.
2. **Missing `presentationContextProviding`** on `ASAuthorizationController` — undocumented behavior on iOS 17+.
3. **User cancellation surfaced as error** — tapping Cancel showed an error message to the user.
4. **No cleanup** of retained delegate and nonce after sign-in completes or fails.

## Approach Chosen

### MUST FIX 1: Native SignInWithAppleButton handlers

**Chosen:** Split `signInWithApple()` into a two-step API (`prepareAppleSignIn()` + `completeAppleSignIn()`) for the `SignInWithAppleButton` native flow.

**Why not the custom button alternative?** The CTO offered replacing `SignInWithAppleButton` with a custom `Button` styled per Apple HIG. While simpler, we chose the native approach because:
- Apple's App Store reviewers are more likely to approve the native `SignInWithAppleButton` on the primary login screen (Guideline 4.8).
- The native button handles accessibility, localization, and dark mode automatically.
- SettingsView already uses a custom button (secondary screen), so we have both patterns.

**How it works:**
- `onRequest` calls `prepareAppleSignIn()` → generates nonce, stores it, returns SHA256 hash
- `onCompletion` calls `completeAppleSignIn(credential:)` → creates Firebase credential with raw nonce, signs in
- No overlay, no delegate, no continuation — SwiftUI handles the presentation lifecycle

### MUST FIX 2: presentationContextProviding

Added `ASAuthorizationControllerPresentationContextProviding` conformance to `AuthManager`. This is only needed for the `signInWithApple()` path (SettingsView's custom button), since `SignInWithAppleButton` handles presentation context automatically.

**Pattern reference:** This follows the same window-discovery pattern used in `LoginView.signInGoogle()` and `SettingsViewModel.signInWithGoogle()` — see `UIApplication.shared.connectedScenes`.

### iOS-GOTCHA: Silence cancellation

Added `AuthError.userCancelled` case. The delegate now detects `ASAuthorizationError.canceled` and throws `userCancelled` instead of `appleSignInFailed`. Callers filter it:
- **LoginView** (native path): checks `ASAuthorizationError.canceled` in `onCompletion`'s `.failure` case
- **SettingsViewModel**: catches `AuthError.userCancelled` and silently returns

### SUGGESTION: defer cleanup

Added `defer { _appleSignInDelegate = nil; currentNonce = nil }` at the top of `signInWithApple()`. Also added `defer { currentNonce = nil }` in `completeAppleSignIn()`.

## Files Modified

| File | Change |
|------|--------|
| `AuthManager.swift` | Added `prepareAppleSignIn()`, `completeAppleSignIn()`, `presentationContextProviding`, `AuthError.userCancelled`, defer cleanup, cancellation detection in delegate |
| `LoginView.swift` | Replaced overlay hack with native `onRequest`/`onCompletion`, removed `signInApple()` method |
| `SettingsViewModel.swift` | Added `AuthError.userCancelled` catch in `signInWithApple()` |
| `AppleSignInTests.swift` | Added `test_errorDescription_userCancelled_returnsNil` test |

## Patterns Referenced

- **Two-step auth API pattern**: Similar to how `GIDSignIn` separates configuration from completion — `AuthManager.swift:56-66`
- **Window discovery**: `UIApplication.shared.connectedScenes` pattern already used in `LoginView.swift:111-113` and `SettingsViewModel.swift:154-156`
- **Error filtering**: Follows the convention of specific error types enabling `catch` pattern matching — `AuthError` enum in `AuthManager.swift:170-190`

## Potential Risks & TODOs

- **Race condition on `currentNonce`**: If `onRequest` fires twice before `onCompletion` (edge case with rapid taps), the second nonce overwrites the first. Mitigation: `SignInWithAppleButton` is disabled while `isSigningIn` is true, and `onRequest` fires synchronously before the system presents the sheet.
- **TODO**: Extract `AuthManagerProtocol` for proper unit testing of SettingsViewModel's Apple Sign-In flow (noted in `AppleSignInTests.swift`).
- **TODO**: Consider consolidating the two sign-in paths if SettingsView moves to `SignInWithAppleButton` in the future.

## Key Concepts for Mentor (Sage)

1. **`SignInWithAppleButton` lifecycle**: `onRequest` is synchronous and called before the Apple sheet appears. `onCompletion` is called after the user completes or cancels.
2. **Nonce security**: Firebase requires the raw nonce for credential creation but only the SHA256 hash is sent to Apple. This prevents replay attacks.
3. **`withCheckedThrowingContinuation`**: Bridges callback-based APIs to async/await. Used in the `signInWithApple()` path but not needed for the native `SignInWithAppleButton` path.
4. **`defer` for cleanup**: Ensures resources are released regardless of success/failure path — critical for retained references like the delegate.
5. **Error type hierarchies**: Using specific `AuthError.userCancelled` enables clean `catch` pattern matching at the call site, avoiding string comparison on error messages.
