# Code Review Summary: COD-21 — Clear cached _homeViewModel on auth state change

**Date**: 2026-04-03
**Reviewer**: Lens (Code Reviewer)
**Author**: Forge (Senior Engineer)
**Branch**: `feature/COD-21-progress-reset-fix`
**PR**: [#10](https://github.com/eason034056/codereps/pull/10)
**Related**: COD-20 (parent bug), `docs/decisions/006-progress-reset-after-login.md`

---

## Verdict: APPROVE

The fix is correct, minimal, and well-reasoned. No blocking issues found.

---

## Review Comments

### [PRAISE] Surgical, minimal fix — exactly the right approach

The entire fix is one line:
```swift
self._homeViewModel = nil   // Clear cached ViewModel so it rebuilds with new repos
```

This leverages the existing lazy re-creation pattern (`DIContainer.swift:161-172`) instead of adding new machinery. The fix is placed in the correct location — alongside the existing repo invalidation (lines 108-110) in the auth state change listener. This is textbook cache invalidation: when the upstream dependency changes, invalidate the downstream cache.

### [PRAISE] Excellent decision documentation

`docs/decisions/006-progress-reset-after-login.md` is thorough:
- Clear root cause analysis (cached ViewModel holds stale repo reference)
- Three alternatives considered with specific pros/cons
- Explains why the fix is safe (HomeView uses `@ObservedObject`, not `@StateObject`)
- Trade-off table is concise and honest

This is the quality of decision documentation that makes a codebase maintainable long-term.

### [PRAISE] Good test strategy despite concrete AuthManager limitation

Since `AuthManager` is a concrete `final class` (not protocol-based), directly testing the auth listener wiring isn't possible. The tests smartly verify the **observable effects** instead:
- Fresh ViewModel with correct repos shows data (`test_freshHomeViewModel_showsCorrectProgress`)
- Stale ViewModel with empty repo shows zero (`test_staleViewModel_emptyRepo_showsZeroProgress`)
- Two different repos produce different ViewModel state (`test_differentRepos_produceDifferentViewModelState`)

This is a pragmatic testing approach given the constraint.

### [SUGGESTION] Untracked test files should be committed to the branch

The following files exist in the working directory but are NOT part of the commit:
- `LeetCodeLearnerTests/Domain/ProgressResetBugFixTests.swift` (11 tests)
- `LeetCodeLearnerTests/Data/MigrateOrphanedDataTests.swift` (11 tests)
- `LeetCodeLearner.xcodeproj/project.pbxproj` (staged but not committed)
- `docs/decisions/006-progress-reset-after-login.md`

These should be committed to the branch before merge so the test coverage ships with the fix.

### [SUGGESTION] Unstaged ChatView.swift change is unrelated to COD-21

There's an unstaged change in `ChatView.swift` adding `isInputFocused = false` after `sendMessage()` (keyboard dismiss on send). This is unrelated to the progress reset fix and should be tracked as a separate task to keep the PR focused.

### [iOS-GOTCHA] Combine `sink` and @MainActor isolation

The auth listener uses `sink` on a `@Published` property publisher:
```swift
authManager.$currentUser
    .map { $0?.userId ?? "" }
    .removeDuplicates()
    .sink { [weak self] newUserId in
        // ... mutates @MainActor state
    }
```

In Swift 5.9+ with strict concurrency, this works because the closure captures `[weak self]` where `self` is `@MainActor`, so the closure body inherits main actor isolation. However, this is a subtle guarantee. Adding `.receive(on: DispatchQueue.main)` before `sink` would make the threading contract explicit. **Not blocking** — this is pre-existing behavior, not introduced by this PR.

### [QUESTION] Should other cached ViewModels be guarded proactively?

Currently only `_homeViewModel` is cached (line 159). `ReviewQueueViewModel`, `LearningPathsViewModel`, and `ChatViewModel` are all factory-created fresh. If future development adds caching to any other ViewModel, the same stale-reference bug will recur. Consider adding a comment near the auth listener noting that **any newly cached ViewModel must also be cleared here**.

---

## Architecture Consistency Assessment

| Check | Result |
|-------|--------|
| Clean Architecture layers respected | ✅ No layer violations |
| @MainActor correctness | ✅ DIContainer is @MainActor, mutation in sink is safe |
| SwiftData thread safety | ✅ No cross-thread ModelContext usage |
| Memory management | ✅ `[weak self]` in sink prevents retain cycle |
| Design system compliance | N/A (no UI changes) |
| Firebase security | N/A (no Firestore rule changes) |
| Follows existing DI pattern | ✅ Same cache invalidation approach as repos |

---

## What the Engineer Did Well

1. **Minimal change** — Resisted the temptation to refactor or add unnecessary abstractions
2. **Implementation notes** — Clear documentation of thought process and alternatives
3. **Correct placement** — The nil assignment is in the exact right location in the auth listener
4. **Conventional commit message** — `fix: clear cached _homeViewModel on auth state change (COD-21)`

## Improvement Suggestions for Future Work

1. **Extract `AuthManagerProtocol`** — Would enable full integration testing of the auth listener wiring. Currently the biggest testing gap in the codebase.
2. **Defensive comment** — A brief note near the auth listener: "If you add a new cached ViewModel, remember to clear it here."
3. **Consider a `invalidateAllCaches()` method** — As the number of cached objects grows, having a single method called from the auth listener would be more maintainable than adding individual nil assignments.

---

*This review summary is for Sage (Mentor) to use in teaching materials.*
