# Code Review Summary: COD-29 — Weekly Review Schedule — Collapsible Summary Card

**Date**: 2026-04-06
**Reviewer**: Lens (Code Reviewer)
**Author**: Swift (Senior Engineer)
**Branch**: `feature/COD-29-weekly-schedule-card`
**Related**: COD-29 (parent plan), COD-31 (implementation task), `docs/decisions/008-weekly-review-schedule-card.md`

---

## Verdict: APPROVE with SUGGESTIONS

The implementation is solid — clean component decomposition, consistent DesignTokens usage, correct state ownership, and good accessibility coverage. Two suggestions for robustness and one minor performance note, but nothing blocking merge.

---

## Review Comments

### [PRAISE] Excellent DesignTokens compliance

Every visual property uses the design system:
- Colors: `AppColor.cardBackground`, `AppColor.accent`, `AppColor.cardBorder`, `AppColor.success`
- Spacing: `AppSpacing.xs/sm/md/lg/xl/xxl` throughout
- Fonts: `AppFont.headline`, `.caption`, `.callout`, `.subheadline`, `.caption2`
- Radius: `AppRadius.large`
- Animation: `AppAnimation.springDefault`
- Shadows: `.cardShadow()`

Zero hardcoded colors or spacing values. This is exemplary.

### [PRAISE] Clean component decomposition

`WeekDayIndicatorStrip` is a pure, stateless component that takes `reviewCounts` + `todayIndex`. It has no knowledge of the data source — fully reusable. `WeeklyScheduleCard` owns its own `@State isExpanded` (correctly at the View layer, not ViewModel), and receives data via plain properties. This follows the plan's architecture exactly.

### [PRAISE] Correct @State vs @Published ownership

- `isExpanded` → `@State` in `WeeklyScheduleCard` ✅ (view-local UI state)
- `weeklyGroups` / `weeklyTotalCount` → `@Published` in `ReviewQueueViewModel` ✅ (data from repository)

This is exactly what the plan specified and matches SwiftUI best practices.

### [PRAISE] Solid VoiceOver accessibility

Every interactive element has accessibility labels:
- Each dot: day name + count ("Monday: 2 reviews")
- Header button: "Collapse/Expand weekly schedule" with hint
- Card container: "Weekly review schedule, N reviews this week"
- Problem rows: title + difficulty + topic + "Opens problem chat" hint
- Day headers: `.isHeader` trait

### [SUGGESTION] `DateFormatter` allocation in `dayLabel(for:)` and `accessibilityLabel(index:count:)`

**File**: `WeeklyScheduleCard.swift:154-167`, `WeekDayIndicatorStrip.swift:77-82`

Both methods allocate a new `DateFormatter()` on every call. While the card count is small (typically <7 groups), `DateFormatter` is notoriously expensive to create. Consider hoisting to a `static let` or a cached property, similar to how `WeekDayIndicatorStrip` already does it correctly for `weekdaySymbols` (line 15-20).

```swift
// Suggested pattern (already used in WeekDayIndicatorStrip):
private static let weekdayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEEE"
    return f
}()
```

**Why this matters**: `DateFormatter` init involves ICU data loading. With 5-7 groups, this creates 5-7 formatters per render. Not a blocking issue for this card count, but it's a good habit.

### [SUGGESTION] `reviewCountsByWeekday` computed property recalculates on every body evaluation

**File**: `WeeklyScheduleCard.swift:16-24`

`reviewCountsByWeekday` is a computed property on the View struct, so it's recalculated every time SwiftUI evaluates the body. For a small data set this is fine, but if the card is within an animated container, it could be called frequently during animation frames.

Consider: this is acceptable given the data size (≤7 groups), but worth noting for future similar patterns with larger datasets.

### [PRAISE] Smart integration approach in ReviewQueueView

The integration wraps the existing content in a `ScrollView > VStack` pattern, places the weekly card above the flashcard flow, and correctly:
- Hides when `weeklyTotalCount == 0` (no empty card shown)
- Preserves the weekly card after flashcard completion (`completedView` is inside the same ScrollView)
- Adds `.scrollIndicators(.hidden)` for clean UX
- Calls `loadDueCards()` which chains to `loadWeeklyCards()` — single data load

### [QUESTION] Empty state text not updated per plan

**File**: `ReviewQueueView.swift:147-160`

The plan specified updating `emptyView` text to: *"No reviews due today. Check your upcoming schedule above."* when weekly cards exist but today has none. The current implementation keeps the original text: *"Start solving problems to build your review queue."*

Was this intentional? The current text still makes sense, but the plan's version would help users discover the weekly card.

### [iOS-GOTCHA] `Calendar.dateInterval(of: .weekOfYear)` respects locale

**File**: `ReviewQueueViewModel.swift:45`

`Calendar.current.dateInterval(of: .weekOfYear, for: now)` uses the device's locale to determine week start (Sunday in US, Monday in ISO/EU). This is **correct behavior** — it matches `veryShortWeekdaySymbols` in `WeekDayIndicatorStrip` which also uses `Locale.current`. Both align, so the dots will match the data.

Just flagging that this is locale-dependent by design — if you ever hardcode `Calendar(identifier: .gregorian)` elsewhere, these would diverge.

---

## Architecture Assessment

| Check | Result |
|-------|--------|
| Clean Architecture layers | ✅ View → ViewModel → Repository. No View→Repo shortcuts |
| Domain entity purity | ✅ `SpacedRepetitionCard` and `Problem` are used as-is, no framework leakage |
| DesignTokens compliance | ✅ 100% — no hardcoded colors, fonts, spacing, or radii |
| @MainActor correctness | ✅ `ReviewQueueViewModel` is `@MainActor` |
| SwiftData thread safety | ✅ All repo calls happen on `@MainActor` ViewModel |
| Memory management | ✅ No closures capturing self, no retain cycle risk |
| Navigation pattern | ✅ `NavigationLink(value: Problem)` matches existing `navigationDestination` in ContentView |

---

## What the engineer did well

1. **Followed the plan precisely** — file placement, component responsibilities, data flow all match the architecture design
2. **Consistent design system usage** — zero DesignTokens violations across 250+ lines of new code
3. **Locale-aware calendar** — both the data grouping and the weekday labels respect the user's locale
4. **Accessibility-first** — every interactive element has VoiceOver support, including `.isHeader` traits on section headers
5. **Minimal touch surface** — no unnecessary changes to existing code; `loadDueCards()` simply chains to `loadWeeklyCards()`

## Improvement suggestions for future work

1. **Cache `DateFormatter` instances** — static properties are the standard pattern (already used in `WeekDayIndicatorStrip.weekdaySymbols`)
2. **Consider the plan's `emptyView` text update** — small UX win for discoverability
3. **Add `#Preview` macros** — would help with visual iteration on the components in Xcode

---

## Summary for Sage (Mentor)

This PR demonstrates strong understanding of:
- **Component decomposition**: Stateless indicator strip vs. stateful card container
- **@State vs @Published**: Correct ownership boundary between View-local UI state and ViewModel data
- **DesignTokens discipline**: Internalizing the design system as the default, not an afterthought
- **Accessibility patterns**: `.accessibilityElement(children:)`, `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityAddTraits`

Teaching opportunities:
- **DateFormatter performance**: Good chance to explain why iOS devs cache formatters (ICU overhead, WWDC talks)
- **Computed properties in SwiftUI View structs**: When recalculation matters vs. when it's negligible
- **Locale-aware Calendar APIs**: The student correctly used `Calendar.current` — reinforce why this matters for internationalization
