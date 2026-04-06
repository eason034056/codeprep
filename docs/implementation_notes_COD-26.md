# Implementation Notes: COD-26 — SR Card Creation in UMPIRE Flow

## Problem Statement

When users complete a LeetCode problem through the Chat/UMPIRE flow, `markUMPIRESolutionDelivered()` updates their `UserProblemProgress` (status, lastAttemptDate, umpireSolutionUnlocked) but **never creates a SpacedRepetitionCard**. This means:
- The Review Queue stays empty for UMPIRE-solved problems
- SM-2 spaced repetition scheduling never kicks in
- The primary learning path (Chat/UMPIRE) is completely disconnected from spaced repetition

## Thinking Process

### Root Cause Analysis

There are **two code paths** that can complete a problem:

1. **Review Queue path** (`UpdateSpacedRepetitionUseCase`) — already creates SR cards correctly (lines 13-16)
2. **Chat/UMPIRE path** (`EvaluateUserApproachUseCase.markUMPIRESolutionDelivered()`) — missing card creation entirely

The bug is a simple omission: when `markUMPIRESolutionDelivered()` was originally written, the card creation step was never added.

### Alternatives Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| **A. Add card creation directly in `markUMPIRESolutionDelivered()`** | Simple, follows existing pattern, minimal blast radius | Slight duplication with `UpdateSpacedRepetitionUseCase` | **Chosen** |
| B. Extract shared card-creation helper | DRY principle | Over-engineering for 3 lines of code; premature abstraction | Rejected |
| C. Call `UpdateSpacedRepetitionUseCase` from within `markUMPIRESolutionDelivered()` | Reuses existing logic | Creates circular dependency concerns; `UpdateSpacedRepetitionUseCase` also updates progress status which would conflict | Rejected |
| D. Event-driven: post notification, have SR subsystem listen | Decoupled | Too complex for this fix; introduces async timing issues | Rejected |

### Why Option A

The card creation is exactly 3 lines (the same pattern as `UpdateSpacedRepetitionUseCase` lines 13-16):
```swift
var card = progressRepo.getOrCreateCard(for: problemId)
card = sm2.update(card: card, quality: quality)
progressRepo.saveCard(card)
```

Three similar lines of code is better than a premature abstraction. If a third code path emerges in the future, then extracting a helper makes sense.

### Quality Rating Mapping

- `solvedIndependently` → quality **4** (minor hesitation — user solved it on their own before)
- Everything else (primarily `solvedWithHelp`) → quality **3** (serious difficulty — UMPIRE walked them through it)

This maps to SM-2's standard 0-5 scale where 3 = "correct response recalled with serious difficulty" and 4 = "correct response after hesitation".

## Changes Made

### 1. `EvaluateUserApproachUseCase.swift` (Core/Domain/UseCases/)
- Added `SM2Algorithm` as a private dependency with default value
- Added card creation logic in `markUMPIRESolutionDelivered()` after progress update
- Quality is determined by reading the progress *after* the update closure runs

### 2. `DIContainer.swift` (App/)
- Passed existing `sm2` instance to `EvaluateUserApproachUseCase` init
- Follows exact same pattern as `UpdateSpacedRepetitionUseCase` DI (line 58)

### 3. `UMPIRESRCardCreationTests.swift` (Tests/Domain/)
- 17 tests covering: card creation, SM-2 state verification, duplicate prevention, quality mapping, daily challenge integration, edge cases, full lifecycle, and cross-flow consistency

## Patterns Referenced

| Pattern | File | Lines |
|---------|------|-------|
| Card creation (getOrCreate → update → save) | `UpdateSpacedRepetitionUseCase.swift` | 13-16 |
| SM2Algorithm injection with default | `UpdateSpacedRepetitionUseCase.swift` | 7 |
| DI container SM2 injection | `DIContainer.swift` | 57-59 |
| Test setup with MockChatRepository (@MainActor) | `StreakCountingAfterUMPIRETests.swift` | 16-25 |
| TestHelpers.makeProgress / makeCard | `TestHelpers.swift` | 31-67 |

## Potential Risks & TODOs

1. **Double card update if both paths fire**: If a user somehow triggers both the UMPIRE flow and the Review Queue for the same problem in quick succession, the card will be updated twice. This is safe because `getOrCreateCard` is idempotent and SM-2 updates are deterministic for the same quality input.

2. **Firestore sync**: The `saveCard()` method sets `syncStatus = "pendingUpload"`, so the new card will be synced to Firestore on the next sync cycle. No additional sync changes needed.

3. **Thread safety**: All operations go through `ProgressRepository` which uses `modelContainer.mainContext` — this is already `@MainActor`-bound, matching how `ChatViewModel` calls `markUMPIRESolutionDelivered()`.

## Key Takeaways for Teaching

1. **Two code paths, one side effect**: The bug existed because the app had two ways to "complete" a problem, but only one created SR cards. Always trace all code paths that modify shared state.
2. **Follow existing patterns**: The fix is 3 lines that mirror an existing, working pattern — no need to invent new abstractions.
3. **Quality mapping is a domain decision**: Mapping `solvedWithHelp → 3` and `solvedIndependently → 4` is a product/pedagogical choice, not a technical one.
4. **Test both paths, verify consistency**: The `test_consistency_umpireAndReviewQueue_produceCompatibleCards` test ensures both flows produce structurally identical SM-2 state.
