# Decision Log 008: Weekly Review Schedule — Collapsible Summary Card (COD-29)

**Date:** 2026-04-06
**Author:** Archon (CTO)
**Status:** Decided

## Context

The Review page currently only shows "today's due" flashcards. Users can't preview their upcoming review workload for the week. This makes spaced repetition feel like a black box — users don't know when or how many reviews are coming.

**Goal:** Add a collapsible "This Week" summary card above the flashcard flow, showing daily review distribution with tap-to-navigate to problem chats.

## Decision

**Chosen: Approach B — Collapsible Weekly Summary Card + Tap-to-Navigate**

### Architecture

- **No new repository methods needed** — reuse `getDueCards(before: endOfWeek)` and group client-side by `Calendar.startOfDay(for: card.nextReviewDate)`
- **2 new View components** in `Features/Review/Components/`:
  - `WeekDayIndicatorStrip` — 7-day dot indicator showing review density
  - `WeeklyScheduleCard` — collapsible card with per-day problem list
- **1 ViewModel extension** — add `weeklyGroups` + `loadWeeklyCards()` to existing `ReviewQueueViewModel`
- **1 View modification** — integrate into `ReviewQueueView` above flashcard flow
- **No DI changes** — ViewModel already has `progressRepo` and `problemRepo`

### Key Design Decisions

1. **Client-side grouping over new DB query**: The number of weekly cards is small (typically <20). `getDueCards(before:)` + `Dictionary(grouping:)` is simpler than adding a new repo method.

2. **Collapsible by default**: Prevents the summary from stealing focus from the primary flashcard review flow. Users see the density dots at a glance, expand for details.

3. **NavigationLink(value: Problem)**: Reuses existing `navigationDestination(for: Problem.self)` handler in ContentView — zero navigation plumbing needed.

4. **Exclude today's due cards from weekly view**: They're already visible in the flashcard queue below. Avoids confusion from seeing the same cards twice.

## Alternatives Considered

### Approach A: Full Calendar View

A monthly calendar overlay showing all review dates.

**Rejected because:**
- Overkill for the problem scope — most users only care about this week
- Requires significant new UI infrastructure (custom calendar grid)
- Doesn't integrate naturally with the flashcard flow

### Approach C: Separate "Schedule" Tab

A dedicated tab showing the weekly/monthly review schedule.

**Rejected because:**
- Fragments the review experience across two tabs
- Users would need to switch tabs to see what's coming
- Adds navigation complexity for a simple feature

## Impact Assessment

- **Files created:** `WeekDayIndicatorStrip.swift`, `WeeklyScheduleCard.swift`
- **Files modified:** `ReviewQueueViewModel.swift`, `ReviewQueueView.swift`
- **Risk:** Low — additive UI feature, no business logic changes
- **Architecture:** Follows existing patterns (ObservableObject, DesignTokens, NavigationLink)
- **Accessibility:** Each dot, day section, and problem row needs VoiceOver labels
- **Performance:** One extra `getDueCards` call with a broader date range — negligible

## Trade-offs

| Factor | Assessment |
|--------|-----------|
| Simplicity | High — reuses existing repo + navigation patterns |
| Discoverability | Good — visible above flashcards, collapsed by default |
| Accessibility | Must add VoiceOver labels for dot density + sections |
| Animation | Spring animation for expand/collapse matches existing app feel |
| Edge cases | Empty state (no weekly cards) = card not shown |
