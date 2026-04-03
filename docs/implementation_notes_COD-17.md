# Implementation Notes: COD-17 — Streak Counting Bug Fix

## Problem Summary

`markUMPIRESolutionDelivered()` in `EvaluateUserApproachUseCase` sets `progress.status = .solvedWithHelp` but never sets `progress.lastAttemptDate`. The streak pipeline relies on `lastAttemptDate` being non-nil to count completions — so first-time UMPIRE chat solves are invisible to `StreakCalculator`.

## Thinking Process

### Root Cause Analysis

The streak pipeline has two requirements for counting a solve:
1. `status` must be `.solvedWithHelp` or `.solvedIndependently` (used as filter)
2. `lastAttemptDate` must be non-nil (the actual date used by `getCompletionDates()`)

`ProgressRepository.getCompletionDates()` uses `compactMap { $0.lastAttemptDate }` — any nil dates are silently dropped. Since `markUMPIRESolutionDelivered()` never sets the date, these solves never appear in streak calculations.

### Why Only Spaced Repetition Worked

`UpdateSpacedRepetitionUseCase.execute()` (line 21) correctly sets `progress.lastAttemptDate = Date()`. But that's the **review** flow — it only runs when re-reviewing a previously-solved problem. First-time solves through chat never triggered it.

### Fix Location

I placed `progress.lastAttemptDate = Date()` **before** the status `if` block inside the `updateProgress` closure. This ensures the date is always recorded regardless of current status — even if a user re-solves a problem that's already `.solvedWithHelp`, the date still updates to reflect the latest activity.

### Alternatives Considered

1. **Set date in `markApproachConfirmed()` instead** — Rejected: approach confirmation doesn't mean the full solution was delivered. The date should reflect actual solve completion.

2. **Change `getCompletionDates()` to use SwiftData's `lastModified`** — Rejected: `lastModified` updates on Firestore sync too, creating false positives in streak calculations.

3. **Add a separate `[Date]` completion history array** — Rejected: over-engineered for this fix. The one-date-per-problem model works fine for streak counting (one solve per problem contributes one day).

## Patterns Referenced

- **Existing pattern followed:** `UpdateSpacedRepetitionUseCase.swift:21` — same approach of setting `lastAttemptDate = Date()` inside `progressRepo.updateProgress` closure
- **Domain entity:** `UserProblemProgress.swift:9` — `lastAttemptDate: Date?`
- **Streak pipeline:** `ProgressRepository.swift:194` — `return progress.lastAttemptDate` used in `getCompletionDates()`
- **Decision log:** `docs/decisions/005-streak-counting-bug-fix.md` — full analysis by CTO

## Potential Risks

- **Existing data:** Users who already solved via UMPIRE chat have `nil` dates. Their streaks won't recover retroactively. Acceptable at current scale — could add a migration later if needed.
- **Date overwrite on re-solve:** If a user re-reviews a problem via spaced repetition, `lastAttemptDate` gets overwritten. This is a pre-existing design limitation noted in the decision log — not introduced by this fix.

## TODO

- Consider adding a unit test that specifically verifies `lastAttemptDate` is set after `markUMPIRESolutionDelivered()` — requires a mock `ProgressRepository` that captures the closure mutation.
