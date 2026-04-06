# Code Review Summary: COD-27 — SR Card Creation in UMPIRE Flow

**Date**: 2026-04-06
**Reviewer**: Lens (Code Reviewer)
**Author**: Forge (Senior Engineer)
**Branch**: `feature/COD-26-sr-card-creation-fix`
**Parent Issue**: [COD-24](/COD/issues/COD-24)
**Decision Log**: `docs/decisions/007-spaced-repetition-card-creation-bug.md`

---

## Verdict: APPROVE

The fix is correct, consistent with existing patterns, and well-tested. No blocking issues found.

---

## Review Comments

### [PRAISE] Card creation pattern is a perfect mirror of UpdateSpacedRepetitionUseCase

`EvaluateUserApproachUseCase.swift:56-58`:
```swift
var card = progressRepo.getOrCreateCard(for: problemId)
card = sm2.update(card: card, quality: quality)
progressRepo.saveCard(card)
```

This is identical to `UpdateSpacedRepetitionUseCase.swift:13-16`. The engineer correctly identified the canonical pattern and replicated it rather than inventing a new approach. The comment at line 46 explicitly references the source (`"Pattern mirrors UpdateSpacedRepetitionUseCase lines 13-16"`), which is excellent traceability.

### [PRAISE] Quality mapping is well-reasoned and correct

`EvaluateUserApproachUseCase.swift:49-55`:

| Status | Quality | SM-2 Meaning | Rationale |
|--------|---------|-------------|-----------|
| `solvedIndependently` | 4 | Correct with minor hesitation | User previously solved independently; re-triggering UMPIRE is a refresher |
| Everything else (typically `solvedWithHelp`) | 3 | Correct with serious difficulty | User needed UMPIRE guidance to solve |

The quality determination reads the status **after** the `updateProgress` closure executes. This is intentional and correct:
- For `.unseen` / `.attempted` problems: closure upgrades to `.solvedWithHelp` → quality 3
- For `.solvedIndependently` problems: closure doesn't downgrade → quality 4
- For `.solvedWithHelp` problems (repeat UMPIRE): closure no-ops → quality 3

### [PRAISE] DI injection is minimal and clean

`DIContainer.swift:66`:
```swift
EvaluateUserApproachUseCase(chatRepo: chatRepo, progressRepo: progressRepo, sm2: sm2)
```

Uses the existing `sm2` singleton instance (line 42: `let sm2 = SM2Algorithm()`). No new objects created, no structural changes to the DI graph. The default parameter in the init (`sm2: SM2Algorithm = SM2Algorithm()`) preserves backward compatibility if the use case were constructed elsewhere.

### [PRAISE] Test coverage is comprehensive

`EvaluateUserApproachUseCaseTests.swift` — 6 tests covering:

| Test | What It Verifies |
|------|-----------------|
| `test_...createsCardForNewProblem` | Core fix: card is created, saveCard called once, correct quality/repetitionCount |
| `test_...updatesExistingCard` | Idempotency: no duplicate cards when card already exists |
| `test_...usesQuality4ForSolvedIndependently` | Quality mapping edge case |
| `test_...setsNextReviewDateInFuture` | SM-2 output validation |
| `test_...updatesProgressStatus` | Regression: existing behavior preserved |
| `test_...marksDailyChallengeCompleted` | Regression: daily challenge still works alongside card creation |

The tests use `@MainActor` correctly (required because `MockChatRepository` is `@MainActor`), and inject a real `SM2Algorithm()` rather than mocking it — verifying the full integration from use case through SM-2 to card output.

### [SUGGESTION] Add test for repeat UMPIRE completion (same problem, twice)

The existing tests verify creating a new card and updating an existing card, but they don't test calling `markUMPIRESolutionDelivered` **twice in sequence** for the same problem. This would verify:
1. Second call updates the existing card (no duplication)
2. `repetitionCount` increments from 1 to 2
3. `interval` grows according to SM-2 formula

```swift
func test_markUMPIRESolutionDelivered_calledTwice_updatesCardCorrectly() {
    let problemId = 99
    progressRepo.progressEntries[problemId] = TestHelpers.makeProgress(
        problemId: problemId, status: .unseen
    )
    
    sut.markUMPIRESolutionDelivered(problemId: problemId)
    sut.markUMPIRESolutionDelivered(problemId: problemId)
    
    XCTAssertEqual(progressRepo.cards.count, 1, "Should still be one card")
    XCTAssertEqual(progressRepo.saveCardCallCount, 2)
    XCTAssertEqual(progressRepo.lastSavedCard?.repetitionCount, 2)
}
```

Not blocking — the current coverage is sufficient for the fix.

### [SUGGESTION] Comment on quality-read ordering

`EvaluateUserApproachUseCase.swift:49-55`: The quality check reads status **after** the `updateProgress` closure has already modified it. This is correct behavior but could confuse future readers who might assume the quality determination uses the **pre-update** status. A one-line comment would help:

```swift
// 💡 Quality reads the UPDATED status — the closure above has already
//    set status to .solvedWithHelp for unseen/attempted problems.
let quality: Int
```

### [QUESTION] Line reference accuracy in comment

`EvaluateUserApproachUseCase.swift:46`:
```swift
//    Pattern mirrors UpdateSpacedRepetitionUseCase lines 13-16.
```

Line numbers in code comments become stale over time. Consider referencing the method name instead: `"Pattern mirrors UpdateSpacedRepetitionUseCase.execute()"`.

---

## Architecture Consistency Assessment

| Check | Result |
|-------|--------|
| Clean Architecture layers respected | ✅ Use Case depends only on protocols (`ProgressRepositoryProtocol`) and value types (`SM2Algorithm`) |
| @MainActor correctness | ✅ `EvaluateUserApproachUseCase` is not `@MainActor` — correct, as it has no UI dependencies |
| SwiftData thread safety | ✅ No cross-thread ModelContext usage — repo calls go through protocol |
| Memory management | ✅ No closures capturing self |
| Design system compliance | N/A (no UI changes) |
| Firebase security | N/A (no Firestore rule changes) |
| Follows existing DI pattern | ✅ Same injection style as `UpdateSpacedRepetitionUseCase` |
| SM-2 consistency | ✅ Quality mapping aligns with SM-2 standards (3 = recalled with difficulty, 4 = minor hesitation) |
| No double-counting | ✅ `updateProgress` updates status/date, card creation is a separate step — no overlap with Review Queue flow |

---

## What the Engineer Did Well

1. **Surgical fix** — 3 new lines of card creation logic + 1 DI injection change. No unnecessary refactoring.
2. **Pattern consistency** — Exact same `getOrCreateCard → sm2.update → saveCard` sequence as the existing use case.
3. **Thorough testing** — 6 tests covering the fix, edge cases, and regression verification.
4. **Decision documentation** — Doc 007 clearly explains the root cause (two code paths), the chosen fix, and rejected alternatives.
5. **Default parameter** — `sm2: SM2Algorithm = SM2Algorithm()` is pragmatic for testability without breaking existing callers.

## Improvement Suggestions for Future Work

1. **Extract `AuthManagerProtocol`** — Still the biggest testing gap in the codebase (flagged in COD-21 review, remains open).
2. **Consider SM-2 quality as an enum** — Replace magic numbers `3` and `4` with a `SM2Quality` enum for self-documenting code.
3. **Backfill migration** — Existing users who solved through UMPIRE before this fix still have no cards. Decision doc 007 notes that `getOrCreateCard` handles this on next Review Queue interaction, but a one-time backfill would provide a better experience.

---

*This review summary is for Sage (Mentor) to use in teaching materials.*
