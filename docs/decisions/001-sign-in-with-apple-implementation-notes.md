# Implementation Notes: COD-3 Sign in with Apple

**Author:** Swift (Senior Engineer)
**Date:** 2026-04-03
**Task:** COD-3 — Implement Sign in with Apple (AuthManager + UI + Config)

---

## Thinking Process

### Core Question
How to add Apple Sign-In with minimal architecture disruption while maintaining Firebase credential bridging?

### Key Insight
The existing `AuthManager` uses Firebase's `authStateDidChangeListener` — any auth provider that produces a `Firebase.AuthCredential` automatically triggers the downstream flow. This means:
- Zero changes needed in Domain, Data, DI, or Sync layers
- Only `AuthManager`, UI views, and entitlements need modification

### Approach Chosen: Continuation-Based Async/Await

I wrapped Apple's delegate-based `ASAuthorizationController` in `withCheckedThrowingContinuation` to match the async/await pattern already used by `signInWithGoogle()`. This keeps the two sign-in flows structurally parallel.

### Alternatives Considered

1. **Conform `AuthManager` to `ASAuthorizationControllerDelegate` directly**
   - Rejected: Would add stored continuations and delegate methods directly to the already-growing `AuthManager` class
   - Chosen approach: Separate `AppleSignInDelegate` class keeps responsibility clear

2. **Use `SignInWithAppleButton`'s built-in completion handler**
   - Rejected: The native button runs its own `ASAuthorizationController` flow, but we need to inject a SHA256 nonce for Firebase. Using the button's completion would mean we can't control the nonce.
   - Chosen approach: Use the native button purely for visual compliance, overlay a transparent button that routes to `AuthManager.signInWithApple()`

3. **Create a separate `AppleAuthService` class**
   - Rejected: Per CTO decision doc — over-engineering for a single method. AuthManager is still small (~100 lines of logic)

---

## Potential Risks and TODOs

| Risk | Status | Notes |
|------|--------|-------|
| Apple Sign-In requires real device testing | TODO | Simulator has limited support — QA must verify on physical device |
| Firebase Console must have Apple provider enabled | TODO | Board/ops task — not code-side |
| `_appleSignInDelegate` retention pattern | Monitored | If delegate is deallocated before callback, the continuation will never resume. Retained via class property as mitigation |
| "Hide My Email" relay addresses | OK | Firebase handles relay emails transparently — no special handling needed |
| Account linking (same email via Google + Apple) | OK | Firebase auto-links accounts with matching email |

---

## Patterns Referenced from Existing Codebase

| Pattern | Source File | How Used |
|---------|------------|----------|
| Google Sign-In credential bridging | `AuthManager.swift:51-65` | Mirrored the same flow: get token → create Firebase credential → `Auth.auth().signIn(with:)` |
| `@MainActor` async ViewModel methods | `SettingsViewModel.swift:153-167` | `signInWithApple()` follows the same error-handling Task pattern as `signInWithGoogle()` |
| DesignTokens styling (AppColor, AppFont, AppSpacing) | `DesignTokens.swift` | Used `AppRadius.small`, `AppSpacing.md/lg`, `AppFont.headline` for Apple button in Settings |
| Error handling in LoginView | `LoginView.swift:69-87` | Added parallel `signInApple()` method with identical error/loading state management |
| SettingsSection/SettingsRow components | `SettingsView.swift:349-380` | Apple button placed inside existing SettingsRow component |

---

## Files Changed

1. **`AuthManager.swift`** — Added `signInWithApple()`, nonce helpers, `AppleSignInDelegate`, new `AuthError` cases
2. **`LoginView.swift`** — Added `SignInWithAppleButton`, "or" divider, `signInApple()` function
3. **`SettingsView.swift`** — Added "Continue with Apple" button in Account section
4. **`SettingsViewModel.swift`** — Added `signInWithApple()` method
5. **`LeetCodeLearner.entitlements`** — Added `com.apple.developer.applesignin` capability

## Key Takeaways for Sage (Mentor)

1. **Continuation Bridging** — `withCheckedThrowingContinuation` converts old delegate APIs to modern async/await. The "checked" variant catches double-resume bugs at runtime.
2. **Nonce Security** — Apple Sign-In + Firebase requires a SHA256 nonce to prevent credential replay attacks. The raw nonce goes to Firebase, the hash goes to Apple.
3. **Delegate Retention** — Swift's `ASAuthorizationController` doesn't retain its delegate. Storing it as a class property prevents premature deallocation.
4. **Provider-Agnostic Architecture** — Good auth design means adding a new provider only touches the auth layer. The Firebase state listener decouples "how you sign in" from "what happens after."
5. **Apple HIG Compliance** — The native `SignInWithAppleButton` is required on primary login screens. Secondary screens (like Settings) can use custom-styled buttons.
