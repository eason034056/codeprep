# Decision Log: COD-1 Sign in with Apple

**Date:** 2026-04-03
**Author:** Archon (CTO)
**Status:** Approved
**Issue:** COD-1

---

## Context

CodePrep currently supports Google Sign-In only. Apple requires apps that offer third-party sign-in to also provide Sign in with Apple (App Store Review Guideline 4.8). Adding this is both a compliance requirement and a UX improvement for users who prefer Apple ID.

## Decision

**Add Sign in with Apple as a second authentication method, using `AuthenticationServices` framework + Firebase Auth credential bridging.**

### Approach: Extend `AuthManager` with `signInWithApple()` method

The new method will:
1. Use `ASAuthorizationAppleIDProvider` to request Apple credentials
2. Generate a cryptographic nonce for security (required by Firebase)
3. Bridge the Apple credential to `OAuthProvider.credential(providerID: .apple, ...)` in Firebase Auth
4. Let the existing `authStateDidChangeListener` handle downstream state updates — **zero changes needed** in DIContainer, repositories, or FirestoreSyncService

---

## Alternatives Considered

### Alternative A: Separate `AppleAuthService` class
- **Idea:** Create a dedicated service class `AppleAuthService` following the Single Responsibility Principle
- **Rejected because:**
  - Adds unnecessary indirection — `AuthManager` is only 92 lines today
  - Would require a new protocol and DI registration for a single method
  - Over-engineering for what is essentially one new sign-in flow
  - The downstream auth flow (Firebase credential → state listener → DIContainer) is identical for all providers

### Alternative B: Use `SignInWithAppleButton` (SwiftUI native)
- **Idea:** Use Apple's pre-built `SignInWithAppleButton` view component
- **Partially adopted:**
  - The native button enforces Apple's HIG (black/white pill button)
  - We'll use it **only on LoginView** for compliance
  - On SettingsView we'll use a custom-styled button to match our design system
  - The business logic stays in `AuthManager` regardless of which button triggers it

### Alternative C: Third-party library (e.g., `firebase/FirebaseUI-iOS`)
- **Idea:** Use FirebaseUI's pre-built auth UI for both Google and Apple
- **Rejected because:**
  - Removes control over our custom dark-theme UI
  - Adds a heavy dependency for something achievable in ~60 lines of code
  - Our DesignTokens and AppColor system would be bypassed

---

## Architecture Impact Assessment

| Layer | Impact | Details |
|-------|--------|---------|
| **Infrastructure** | Modified | `AuthManager.swift` — add `signInWithApple()` method, nonce helper, `ASAuthorizationControllerDelegate` |
| **Domain** | None | `AuthenticatedUser` struct unchanged — Firebase maps Apple users the same way |
| **Data** | None | Repositories use `userId` (Firebase UID) — auth provider is irrelevant |
| **DI** | None | `DIContainer` reacts to `authManager.currentUser` changes — provider-agnostic |
| **Sync** | None | `FirestoreSyncService` scoped by `userId` — works with any auth provider |
| **UI (LoginView)** | Modified | Add Sign in with Apple button above/below Google button |
| **UI (SettingsView)** | Modified | Add Apple sign-in option in Account section |
| **Config** | Modified | Entitlements file needs `com.apple.developer.applesignin` capability |
| **Config** | Modified | `project.yml` needs `AuthenticationServices` framework |

### Key Insight
The existing architecture is **excellently designed** for multi-provider auth. Because `AuthManager` uses Firebase Auth's state listener pattern, any new provider just needs to produce a `Firebase.AuthCredential` → everything downstream works automatically.

---

## Implementation Plan (5 Subtasks)

### Task 1: `AuthManager` — Add Apple Sign-In logic
- Add `import AuthenticationServices` and `import CryptoKit`
- Add nonce generation helper (SHA256 hash for Firebase)
- Implement `ASAuthorizationControllerDelegate` + `ASAuthorizationControllerPresentationContextProviding`
- New method: `signInWithApple()` using `async/await` continuation
- Add `AuthError.appleSignInFailed` and `AuthError.missingAppleIDCredential` cases
- Update `signOut()` to be provider-agnostic (already is, but verify)

### Task 2: UI — Update `LoginView`
- Add `SignInWithAppleButton` from AuthenticationServices (Apple HIG compliant)
- Position below the Google button with "or" separator
- Wire to `authManager.signInWithApple()`
- Maintain existing error handling pattern

### Task 3: UI — Update `SettingsView` + `SettingsViewModel`
- Add "Continue with Apple" button in Account section (when not authenticated)
- Add `signInWithApple()` method to `SettingsViewModel`
- Style consistently with existing Google button using DesignTokens

### Task 4: Config — Entitlements & project.yml
- Add `com.apple.developer.applesignin` to `LeetCodeLearner.entitlements`
- Note: `AuthenticationServices` is a system framework, no SPM package needed
- Verify Firebase Console has Apple provider enabled (manual step for board)

### Task 5: Testing & QA
- Test Apple Sign-In flow on device (simulator has limited support)
- Test Google Sign-In still works (regression)
- Test sign-out clears both providers correctly
- Test edge case: same email with Google and Apple (Firebase auto-links)
- Test offline → online sign-in recovery

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Apple Sign-In requires real device + Apple Developer account | QA will verify on physical device; simulator testing limited to UI layout |
| Firebase Apple provider must be enabled in console | Document as prerequisite; board must enable it |
| Email privacy (Apple "Hide My Email" relay) | Firebase handles this — `user.email` may be a relay address, which is fine |
| Account linking (same user, both Google & Apple) | Firebase auto-links accounts with same email; no code needed |

---

## For Sage (Mentor) — Teaching Points

This decision demonstrates several important architecture concepts:

1. **Open-Closed Principle** — AuthManager is open for extension (new sign-in method) but closed for modification (downstream flow unchanged)
2. **Provider-Agnostic Design** — The auth state listener pattern decouples "how you sign in" from "what happens after"
3. **Credential Bridging** — Apple credential → Firebase credential → unified `User` object
4. **Nonce Security** — Why SHA256 nonce is required for Apple Sign-In with Firebase (prevents replay attacks)
5. **Apple HIG Compliance** — When to use native `SignInWithAppleButton` vs custom buttons
