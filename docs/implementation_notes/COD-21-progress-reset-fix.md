# Implementation Notes: COD-21 — Clear cached _homeViewModel on auth state change

## Problem
`DIContainer._homeViewModel` holds a stale `progressRepo` after auth state changes.
Repos are cleared but the cached ViewModel is not, causing the Home tab to display
zero progress after login.

## Approach Taken
Added `self._homeViewModel = nil` in the auth state change listener (line 111 of
`DIContainer.swift`), alongside the existing repo invalidation. This is a one-line
fix that leverages the existing lazy re-creation pattern.

## Why This Approach
The `homeViewModel` computed property (line 161) already re-creates the ViewModel
when `_homeViewModel` is nil. By setting it to nil on auth change, the next access
triggers a fresh ViewModel with the correct repos. `objectWillChange.send()` (line
119) already ensures SwiftUI re-renders ContentView, which accesses `homeViewModel`.

## Alternatives Considered
1. **HomeViewModel observes AuthManager** — Rejected: breaks Clean Architecture
   layer boundaries (ViewModel should not depend on auth)
2. **Reactive repos with Combine** — Rejected: over-engineered, SwiftData predicates
   capture values at construction time
3. **Remove caching entirely** — Rejected: HomeViewModel does work on init
   (daily challenge selection), re-creating on every render is wasteful

See `docs/decisions/006-progress-reset-after-login.md` for full decision log by
Archon (CTO).

## Existing Patterns Referenced
- Cached ViewModel with lazy re-creation: `DIContainer.swift:158-171`
- Auth state listener with repo invalidation: `DIContainer.swift:101-121`
- `ensureRepos()` pattern: `DIContainer.swift:125-143`

## Potential Risks
- None significant. The fix only triggers on auth state change (rare event).
  Other ViewModels (ReviewQueue, LearningPaths) are already created fresh each time.

## TODO
- None. This is a complete, isolated fix.
