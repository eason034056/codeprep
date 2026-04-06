# Decision Log 007: Spaced Repetition Card Creation Bug (COD-24)

**Date:** 2026-04-06
**Author:** Archon (CTO)
**Status:** Decided

## Context

User completed 5 problems (all `solvedWithHelp`) through the Chat/UMPIRE flow, but **zero SpacedRepetitionCard objects were created**. The SM-2 spaced repetition system is completely broken for the primary learning path.

### Root Cause Analysis

There are **two code paths** that mark a problem as "solved":

| Flow | Entry Point | Card Created? |
|------|-------------|---------------|
| **Review Queue** | `ReviewQueueViewModel.rateCard()` → `UpdateSpacedRepetitionUseCase.execute()` | Yes |
| **Chat/UMPIRE** | `ChatViewModel.requestUMPIRESolution()` → `EvaluateUserApproachUseCase.markUMPIRESolutionDelivered()` | **No** |

The `markUMPIRESolutionDelivered()` method correctly updates `progress.status = .solvedWithHelp` but **never calls** `getOrCreateCard()`, `sm2.update()`, or `saveCard()`.

Since users primarily learn through the Chat/UMPIRE flow (not the Review Queue), no cards are ever created for first-time solves.

## Decision

**Chosen: Option A — Inject SM2Algorithm into EvaluateUserApproachUseCase and add card creation directly in `markUMPIRESolutionDelivered()`.**

### Fix Summary

1. Add `SM2Algorithm` as a dependency of `EvaluateUserApproachUseCase`
2. In `markUMPIRESolutionDelivered()`, after updating progress status:
   - Call `progressRepo.getOrCreateCard(for: problemId)`
   - Apply SM2 with `quality: 3` (solved with help) or `quality: 4` (solved independently)
   - Call `progressRepo.saveCard(card)`
3. Update `DIContainer` to inject `SM2Algorithm` into `EvaluateUserApproachUseCase`

### Quality Rating Mapping

- `solvedWithHelp` → quality 3 (correct with serious difficulty)
- `solvedIndependently` → quality 4 (correct with minor hesitation)
- These map to SM-2 standards: 3 = "recalled with difficulty", 4 = "recalled with some hesitation"

## Alternatives Considered

### Option B: Compose at the ViewModel level

Call `UpdateSpacedRepetitionUseCase.execute()` from ChatViewModel after `markUMPIRESolutionDelivered()`.

**Rejected because:**
- `UpdateSpacedRepetitionUseCase.execute()` also increments `attemptCount` and overrides `lastAttemptDate` and `status`, causing **double-counting** with what `markUMPIRESolutionDelivered()` already does.
- Would require refactoring `UpdateSpacedRepetitionUseCase` to separate card-only logic, increasing scope.

### Option C: Extract shared CardCreationService

Create a new `CardCreationService` used by both use cases.

**Rejected because:**
- Over-engineering for a 3-line addition.
- The two use cases have different enough contexts that a shared service adds indirection without proportional value.
- Violates YAGNI — only two call sites, and the Review Queue flow already works correctly.

## Impact Assessment

- **Files changed:** `EvaluateUserApproachUseCase.swift`, `DIContainer.swift`
- **Risk:** Low — additive change, no existing behavior modified
- **Architecture:** Follows existing pattern (SM2Algorithm is already a lightweight struct with no state)
- **Testing:** Add unit test for `markUMPIRESolutionDelivered()` verifying card creation
- **Migration:** Existing users who solved problems through UMPIRE will need a one-time backfill OR the card will be created on their next interaction with the Review Queue (`getOrCreateCard` handles this)

## Trade-offs

| Factor | Assessment |
|--------|-----------|
| Simplicity | High — 3 new lines + 1 dependency injection |
| DRY | Acceptable — SM2 call is small, context differs enough |
| Testability | Good — SM2Algorithm is injectable, easy to test |
| Backward compat | Full — `getOrCreateCard` is idempotent |
