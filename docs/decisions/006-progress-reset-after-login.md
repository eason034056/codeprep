# Decision Log 006: Progress Reset After Login

**Date**: 2026-04-03
**Author**: Archon (CTO)
**Issue**: COD-20 — Fix: 登入後進度被重置

## Problem

Users accumulate local progress while not logged in (userId = ""). After connecting a Google or Apple account, progress "disappears." The data is not deleted — it's still in SwiftData — but the UI shows zero.

### Root Cause

`DIContainer._homeViewModel` is cached (line 158) and holds a stale `progressRepo` reference. When auth state changes:

1. The auth listener (lines 102-120) clears `_currentUserId`, `_progressRepo`, `_chatRepo`
2. But `_homeViewModel` is **not** cleared
3. The cached `HomeViewModel` still holds the old `progressRepo` constructed with the previous userId
4. Even though `migrateOrphanedData()` correctly moves data from userId="" to the new Firebase UID, the ViewModel never re-queries with the new repo

### Why Only HomeViewModel Is Affected

- `ReviewQueueViewModel` and `LearningPathsViewModel` are created fresh by factory methods (`makeReviewQueueViewModel()`, `makeLearningPathsViewModel()`) on each tab switch
- `HomeViewModel` is the only ViewModel cached in `_homeViewModel` for performance (it's on the primary tab)

## Chosen Fix

**Clear `_homeViewModel = nil` in the auth state change listener**, alongside the existing repo invalidation.

```swift
// In auth listener (lines 107-110), add:
self._homeViewModel = nil
```

This ensures the next access to `homeViewModel` creates a fresh instance with the correct repos (and correct userId). SwiftUI picks this up because `objectWillChange.send()` (line 118) already triggers a re-render of ContentView.

### Why This Is Safe

- `HomeView` uses `@ObservedObject` (not `@StateObject`), so it receives whatever instance the parent provides — no ownership conflict
- `objectWillChange.send()` on DIContainer triggers ContentView re-render, which calls `container.homeViewModel` and gets the new instance
- The new `HomeViewModel` will call `loadDailyProblems()` → `loadStreak()` / `loadXP()` with the new repos

### Alternatives Considered

1. **Make HomeViewModel observe auth state and reload**
   - Pro: No cache invalidation needed
   - Con: HomeViewModel gains a dependency on AuthManager, breaking Clean Architecture separation. ViewModel should not know about auth.
   - Rejected: Violates layer boundaries

2. **Make all repos reactive (Combine publishers on userId)**
   - Pro: Elegant, automatic propagation
   - Con: Major refactor — every repo method needs to re-query userId dynamically. SwiftData predicates capture values at construction time.
   - Rejected: Over-engineered for this bug

3. **Remove HomeViewModel caching entirely (always create fresh)**
   - Pro: Simplest — no stale reference possible
   - Con: HomeViewModel does work on init (daily challenge selection). Re-creating on every SwiftUI re-render would be wasteful and could cause visual flicker.
   - Rejected: Performance concern on primary tab

## Trade-offs

| Aspect | Impact |
|--------|--------|
| Code change | 1 line: `self._homeViewModel = nil` in auth listener |
| Performance | Negligible — HomeViewModel only re-created on auth state change (rare event) |
| Architecture | No structural changes; stays within existing DI pattern |
| Risk | Low — other cached ViewModels don't exist; only `_homeViewModel` is affected |

## Verification Plan

1. Use app without login, solve problems, confirm progress shows
2. Connect Google/Apple account
3. Return to Home — progress numbers should remain unchanged
4. Kill and relaunch app — progress persists
5. Logout — progress goes to zero (data migrated to account, anonymous space is empty)
6. Re-login — progress restored
