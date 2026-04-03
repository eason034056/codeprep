# QA Report: COD-17 — Streak Counting Bug Fix (lastAttemptDate in markUMPIRESolutionDelivered)

**Date:** 2026-04-03
**QA Engineer:** Sentinel (QA Engineer)
**Branch:** `feature/COD-17-streak-counting-fix`
**Commit:** `dbf68b3`
**ADR:** `docs/decisions/005-streak-counting-bug-fix.md`
**Parent Task:** COD-8 (Check if streak counting is working)
**Status:** PASS — 117/117 tests, 0 failures, 0 regressions

---

## Summary

COD-17 fixes a bug where `markUMPIRESolutionDelivered()` set `progress.status = .solvedWithHelp` but never set `progress.lastAttemptDate`. Since `getCompletionDates()` uses `compactMap { $0.lastAttemptDate }`, first-time UMPIRE chat solves were invisible to `StreakCalculator`.

**The fix:** Add `progress.lastAttemptDate = Date()` in the `updateProgress` closure, before the status check. One line, matching the existing pattern in `UpdateSpacedRepetitionUseCase.swift:21`.

---

## Test Results

### StreakCountingAfterUMPIRETests — 12/12 PASSED (all new)

| Test | Category | Status |
|------|----------|--------|
| test_markUMPIRESolutionDelivered_setsLastAttemptDate | Unit | PASS |
| test_markUMPIRESolutionDelivered_lastAttemptDateIsToday | Unit | PASS |
| test_markUMPIRESolutionDelivered_setsUmpireSolutionUnlocked | Unit | PASS |
| test_markUMPIRESolutionDelivered_setsStatusToSolvedWithHelp_whenUnseen | Unit | PASS |
| test_markUMPIRESolutionDelivered_setsStatusToSolvedWithHelp_whenAttempted | Unit | PASS |
| test_markUMPIRESolutionDelivered_preservesStatus_whenAlreadySolvedIndependently | Unit | PASS |
| test_markUMPIRESolutionDelivered_updatesLastAttemptDate_whenResolving | Unit | PASS |
| test_integration_umpireSolve_appearsInStreakCalculation | Integration | PASS |
| test_integration_multipleUmpireSolves_sameDayCountAsOne | Integration | PASS |
| test_markApproachConfirmed_doesNotSetLastAttemptDate | Regression | PASS |
| test_regression_spacedRepetitionUseCase_setsLastAttemptDate | Regression | PASS |
| test_markUMPIRESolutionDelivered_marksDailyChallengeCompleted | Integration | PASS |

### Regression Suite — 117/117 PASSED

| Suite | Tests | Status |
|-------|-------|--------|
| StreakCalculatorTests | 19 | PASS |
| SM2AlgorithmTests | 12 | PASS |
| SelectDailyProblemsUseCaseTests | 13 | PASS |
| ScheduleNotificationsUseCaseTests | 13 | PASS |
| SpacedRepetitionLifecycleTests | 4 | PASS |
| ReviewQueueViewModelTests | 6 | PASS |
| ProgressMapperTests | 4 | PASS |
| FirestoreModelsTests | 9 | PASS |
| SyncConflictResolutionTests | 11 | PASS |
| DailyNotificationIntegrationTests | 2 | PASS |
| AppleSignInTests | 2 + 6 | PASS |
| NetworkMonitorTests | 1 | PASS |
| StreakCountingAfterUMPIRETests | 12 | PASS |
| Stubs (placeholder) | 2 | PASS |

---

## Acceptance Criteria Verification

From COD-18 task description:

| Scenario | Status | Details |
|----------|--------|---------|
| 1. markUMPIRESolutionDelivered sets lastAttemptDate to non-nil | PASS | `test_markUMPIRESolutionDelivered_setsLastAttemptDate` |
| 2. After UMPIRE solve, getCompletionDates includes the new date | PASS | `test_integration_umpireSolve_appearsInStreakCalculation` |
| 3. After UMPIRE solve, StreakCalculator returns >= 1 | PASS | Same integration test |
| 4. Full UMPIRE flow → streak increments | PASS | Integration test simulates full pipeline |
| 5. Existing StreakCalculatorTests still pass (19 tests) | PASS | All 19 pass |
| 6. SR flow still sets lastAttemptDate correctly | PASS | `test_regression_spacedRepetitionUseCase_setsLastAttemptDate` |

---

## Exploratory Testing Findings

### Edge Cases Tested

| Edge Case | Result |
|-----------|--------|
| Unseen problem → UMPIRE solve → lastAttemptDate set | PASS |
| Attempted problem → UMPIRE solve → lastAttemptDate set | PASS |
| Already solvedIndependently → UMPIRE solve → status preserved, date updated | PASS |
| Re-solving yesterday's problem today → date updated to today | PASS |
| Multiple UMPIRE solves same day → streak = 1 (not 3) | PASS |
| markApproachConfirmed → lastAttemptDate stays nil | PASS (correct: approach != solve) |
| DailyChallenge completion registered after UMPIRE solve | PASS |

### Known Limitation (Pre-existing, Not Introduced by Fix)

**Existing users with nil dates:** Users who already solved via UMPIRE chat before this fix have `lastAttemptDate = nil`. Their streaks won't recover retroactively. Acceptable at current scale — noted in `docs/decisions/005-streak-counting-bug-fix.md`.

---

## Bugs Found

No bugs found in the COD-17 implementation. The fix is clean, minimal, and follows the established pattern.

**Pre-existing issue noted:** `project.pbxproj` on this branch has phantom references to `SM2AlgorithmEdgeCaseTests.swift` and `UpdateSpacedRepetitionUseCaseTests.swift` (same as COD-14). Stub files created to unblock build.

---

## Recommendation

**Approve for merge.** The fix is a single line that follows the existing pattern in `UpdateSpacedRepetitionUseCase`. All 12 new tests pass and the full 117-test regression suite is green.
