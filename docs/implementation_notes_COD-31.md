# Implementation Notes: COD-31 — Weekly Review Schedule Card

**Date:** 2026-04-06  
**Author:** Swift (Senior Engineer)  
**Branch:** `feature/COD-29-weekly-schedule-card`

## Thinking Process

### Problem
The Review page only showed today's due flashcards. Users had zero visibility into upcoming reviews for the rest of the week, making it hard to plan study sessions.

### Approach Chosen
**Client-side grouping of existing `getDueCards()` data** — no new repository methods, no new entities, no DI changes. This was the lowest-risk approach because:

1. `getDueCards(before: date)` already exists and supports date range filtering
2. Grouping by day is a pure computation (no persistence needed)
3. The ViewModel already holds both `progressRepo` and `problemRepo`, so resolving card→problem pairs is trivial

### Alternatives Considered

1. **New repository method `getWeeklySchedule()`** — Rejected. Would add a SwiftData query that duplicates `getDueCards` with slightly different parameters. Unnecessary abstraction for what is essentially a filter + group operation.

2. **Separate `WeeklyScheduleViewModel`** — Rejected. The data source is identical to `ReviewQueueViewModel`'s repos. Creating a separate VM would mean either duplicating DI wiring or adding a new factory method to DIContainer for no real benefit.

3. **Full Calendar View (Approach A from decision doc)** — Rejected by CTO in decision 008. Overkill for the current need.

## What Was Built

### Files Modified
- `ReviewQueueViewModel.swift` — Added `weeklyGroups`, `weeklyTotalCount`, and `loadWeeklyCards()` method
- `ReviewQueueView.swift` — Wrapped content in ScrollView, added WeeklyScheduleCard above flashcard flow

### Files Created
- `Features/Review/Components/WeekDayIndicatorStrip.swift` — 7-day dot indicator showing review density per day
- `Features/Review/Components/WeeklyScheduleCard.swift` — Collapsible card with header, day indicator strip, and expandable per-day problem list

### Patterns Referenced
- **GamifiedStreakCard** (`Features/Home/Components/GamifiedStreakCard.swift`) — Card styling pattern: `cardBackground` + border overlay + `cardShadow()` + padding with `AppSpacing.lg`
- **DifficultyRatingView** (`Features/Review/Components/DifficultyRatingView.swift`) — Component pattern for Review feature
- **ProblemCardView** (`Features/DailyProblems/Components/ProblemCardView.swift`) — Problem row pattern with difficulty color accent bar
- **HomeView reviewReminderCard** (`Features/Home/HomeView.swift`) — HStack header with icon + text + chevron pattern

### Architecture Decisions
1. **Tuple-based grouping instead of new entity** — `weeklyGroups` is `[(date: Date, cards: [(SpacedRepetitionCard, Problem)])]`. No new struct needed because this is derived display data, not persisted state.

2. **Exclude today's cards** — `startOfTomorrow` filter prevents duplication with the flashcard flow. Today's reviews appear in the main card queue; the weekly card shows only future days.

3. **ScrollView wrapping** — Necessary to support the expanded state. Before this change, the review view was a non-scrollable ZStack. The ScrollView allows both the weekly card and flashcard content to coexist vertically.

4. **NavigationLink(value: Problem)** — Reuses the existing `navigationDestination(for: Problem.self)` handler already defined in the navigation stack parent. No new navigation wiring needed.

## Potential Risks & TODOs

1. **Performance** — `getDueCards(before: endOfWeek)` fetches ALL cards due before end-of-week. For users with hundreds of cards, this could be slow. Currently acceptable for MVP; could add pagination later.

2. **Calendar locale** — `Calendar.current` respects user locale for week start day (Sunday vs Monday). The `weekdayIndex` calculation accounts for this, but edge cases around week boundaries during locale changes are untested.

3. **ScrollView interaction** — Wrapping the flashcard flow in a ScrollView might affect the existing centered layout (Spacers in `cardReviewView`). Verified visually that the VStack with Spacers still centers content within the scroll content area.

4. **`weeklyGroups` is not Equatable** — The tuple array can't be directly compared, so SwiftUI may re-render more than necessary. For now this is fine since `loadWeeklyCards()` only runs on `loadDueCards()` calls (view appear + after rating).

## Key Concepts for Eason (Sage Notes)

- **Dictionary(grouping:)** — Swift's built-in way to partition a collection into groups by a key function. Used here to bucket cards by their `startOfDay`.
- **Calendar.dateInterval(of:for:)** — Returns the start/end of a calendar unit (week, month, etc.) containing a given date. Used to find "end of this week".
- **Transition composition** — `.opacity.combined(with: .move(edge: .top))` chains two transitions for the expand/collapse animation.
- **NavigationLink(value:)** — SwiftUI's type-safe navigation that works with `navigationDestination(for:)` defined higher in the view hierarchy.
