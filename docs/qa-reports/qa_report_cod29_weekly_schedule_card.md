# QA Report: COD-29 / COD-31 — Weekly Review Schedule Collapsible Summary Card

**Date:** 2026-04-06
**QA Engineer:** Sentinel (QA Engineer)
**Branch:** `feature/COD-29-weekly-schedule-card`
**Commit:** `6b80c79` (impl), `b56b2a0` (bug fix)
**Parent Task:** COD-29 (Plan: Weekly Review Schedule)
**Implementation Task:** COD-31, COD-34 (bug fix)
**Status:** PASS — 168/168 tests, 0 failures, 3 bugs found and fixed

---

## Summary

COD-31 implements a collapsible weekly review schedule card above the flashcard flow on the Review tab. The implementation adds:
- `loadWeeklyCards()` in `ReviewQueueViewModel` — fetches cards due this week, groups by day, excludes today
- `WeekDayIndicatorStrip` — 7-dot indicator showing review volume per day
- `WeeklyScheduleCard` — collapsible card with per-day sections and NavigationLink to ChatView
- Integration in `ReviewQueueView` — card placed above existing flashcard flow in ScrollView

---

## Test Results

### New Tests Added — 12/12 PASSED

#### ReviewQueueViewModelTests (8 new weekly schedule tests)

| Test | Category | Status |
|------|----------|--------|
| test_loadWeeklyCards_excludesTodayDueCards | Unit | PASS |
| test_loadWeeklyCards_groupsByDay_sortedAscending | Unit | PASS |
| test_loadWeeklyCards_noCards_emptyGroups | Unit | PASS |
| test_loadWeeklyCards_onlyTodayCards_emptyWeeklyGroups | Unit | PASS |
| test_loadWeeklyCards_totalCountMatchesSumOfGroupCards | Unit | PASS |
| test_loadWeeklyCards_cardWithMissingProblem_skipped | Edge case | PASS |
| test_loadWeeklyCards_cardsAfterWeekEnd_excluded | Edge case | PASS |
| test_loadWeeklyCards_completingFlashcards_weeklyStillPresent | Integration | PASS |

#### WeeklyScheduleCardTests (4 new view component tests)

| Test | Category | Status |
|------|----------|--------|
| test_reviewCountsByWeekday_mapsGroupsToCorrectWeekdaySlots | Unit | PASS |
| test_weekDayIndicatorStrip_padsShortArray | Edge case | PASS |
| test_weekDayIndicatorStrip_truncatesLongArray | Edge case | PASS |
| test_weekDayIndicatorStrip_emptyArray_handledGracefully | Edge case | PASS |

### Regression — 156 existing tests PASSED, 0 failures

---

## Scenario Verification

### Scenario 1: Collapsed State — PASS
- `WeeklyScheduleCard` header shows calendar icon + "This Week: N reviews" + chevron (line 68-85)
- `WeekDayIndicatorStrip` renders 7 dots with color mapping: 0→dim, 1-2→half accent, 3+→full accent (line 68-74 of strip)
- Today marked with accent ring (line 49-53 of strip)

### Scenario 2: Expand/Collapse Animation — PASS
- Uses `@State isExpanded` with `withAnimation(AppAnimation.springDefault)` (line 64)
- Chevron rotates 90° (line 82-83)
- Expanded content uses `.transition(.opacity.combined(with: .move(edge: .top)))` (line 44)

### Scenario 3: Problem Navigation — PASS
- `NavigationLink(value: problem)` matches existing `navigationDestination(for: Problem.self)` in `ContentView.swift:27,44`
- Each problem row shows title, difficulty color bar, problem number, topic (line 121-148)

### Scenario 4: Today's Cards Not Duplicated — PASS
- `loadWeeklyCards()` filters with `$0.nextReviewDate >= startOfTomorrow` (line 52)
- Confirmed by unit test `test_loadWeeklyCards_excludesTodayDueCards`

### Scenario 5: After Completing Flashcards — PASS (with caveat)
- Weekly card visibility depends on `weeklyTotalCount > 0` (ReviewQueueView:13)
- `rateCard()` does NOT re-invoke `loadWeeklyCards()`, so weeklyGroups persist
- Confirmed by unit test `test_loadWeeklyCards_completingFlashcards_weeklyStillPresent`

### Scenario 6: No Cards At All — PASS
- When `weeklyTotalCount == 0`, `WeeklyScheduleCard` is hidden (ReviewQueueView:13)
- `emptyView` displays normally
- Confirmed by test `test_loadWeeklyCards_noCards_emptyGroups`

### Scenario 7: Only Today Has Cards — FAIL (Bug #1)
- When only today has due cards, `weeklyGroups` is empty and `weeklyTotalCount = 0`
- **Expected:** Weekly summary card shows (per plan: visibility = `!weeklyGroups.isEmpty || !dueCards.isEmpty`)
- **Actual:** Weekly card is hidden because `weeklyTotalCount > 0` evaluates to false

---

## Bugs Found

### Bug #1: [Major] Weekly card hidden when only today has due cards

**File:** `ReviewQueueView.swift:13` + `ReviewQueueViewModel.swift:71`

**Repro:**
1. User has SR cards due today but none for the rest of the week
2. Open Review tab

**Expected:** Weekly schedule card shows with today's dot highlighted, "This Week: N reviews" includes today's count
**Actual:** Weekly card is completely hidden

**Root cause:** `weeklyTotalCount` only counts future cards (from `weeklyGroups`), but the plan specifies it should include today's count: `@Published var weeklyTotalCount: Int = 0 — 本週總複習數（含今天）`. The visibility condition `weeklyTotalCount > 0` should be `!weeklyGroups.isEmpty || !dueCards.isEmpty` per the plan.

**Severity:** Major — the feature is invisible for users who only have today's reviews

---

### Bug #2: [Minor] emptyView text not contextually updated

**File:** `ReviewQueueView.swift:147-160`

**Repro:**
1. User has no cards due today, but has cards due later this week
2. Open Review tab

**Expected (per plan):** Text says "No reviews due today. Check your upcoming schedule above."
**Actual:** Text says "Start solving problems to build your review queue." (unchanged from original)

**Severity:** Minor — misleading message when weekly schedule card is visible above

---

### Bug #3: [Minor] weeklyTotalCount header text may confuse users

**File:** `WeeklyScheduleCard.swift:73`

**Related to Bug #1.** The card header says "This Week: N reviews" but N only includes future days, not today's count. Users may expect the total to match their actual weekly workload including today.

**Severity:** Minor — confusing UX, tied to Bug #1 fix

---

## Code Quality Observations

### Positive
- DesignTokens used consistently (43 token references across 2 new files, 0 hardcoded values)
- VoiceOver: 8 accessibility annotations (labels, hints, traits) across new components
- Clean component decomposition: `WeekDayIndicatorStrip` and `WeeklyScheduleCard` are self-contained
- `WeekDayIndicatorStrip.init` safely pads/truncates input array (defensive coding)
- `compactMap` gracefully handles missing problems in ViewModel
- Spring animation via `AppAnimation.springDefault` matches project convention
- HapticManager integration on expand/collapse

### Notes
- `dayLabel(for:)` logic correctly handles "Tomorrow" special case and falls back to weekday name
- Navigation reuses existing `navigationDestination(for: Problem.self)` — no new wiring needed
- `DateFormatter` is created inside the function — for a low-frequency call this is fine, but consider caching if called in hot paths

---

## Test Coverage Summary

| Area | Tests | Status |
|------|-------|--------|
| ViewModel weekly grouping logic | 8 | All pass |
| View component init safety | 4 | All pass |
| Existing regression suite | 156 | All pass |
| **Total** | **168** | **All pass** |

---

## Verdict

**PASS** — All 7 scenarios verified. 3 bugs were found during initial QA and subsequently fixed in COD-34 (`b56b2a0`).

---

## Bug Fix Verification (COD-34)

Commit `b56b2a0` addressed all 3 bugs. Re-verification results:

| Bug | Fix | Verified |
|-----|-----|----------|
| #1 (Major): Weekly card hidden when only today has cards | `weeklyTotalCount` now includes `dueCards.count` | PASS — Scenario 7 now works |
| #2 (Minor): emptyView text not contextual | Conditional text in `emptyView` based on `!weeklyGroups.isEmpty` | PASS |
| #3 (Minor): Header count excludes today | Fixed by Bug #1 — count is now accurate | PASS |

- Tests updated to reflect new `weeklyTotalCount` semantics
- Full suite: **168/168 tests pass, 0 failures, 0 regressions**
