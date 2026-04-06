import SwiftUI

/// Collapsible card showing this week's upcoming review schedule.
///
/// **Collapsed:** calendar icon + "This Week: N reviews" + chevron + WeekDayIndicatorStrip
/// **Expanded:** per-day sections with problem lists, each tappable via NavigationLink.
///
/// Hidden entirely when there are no future cards this week.
struct WeeklyScheduleCard: View {
    let weeklyGroups: [(date: Date, cards: [(SpacedRepetitionCard, Problem)])]
    let totalCount: Int

    @State private var isExpanded = false

    // 💡 Build review counts for each weekday slot (Sun=0..Sat=6)
    private var reviewCountsByWeekday: [Int] {
        let calendar = Calendar.current
        var counts = Array(repeating: 0, count: 7)
        for group in weeklyGroups {
            let weekday = calendar.component(.weekday, from: group.date) - 1 // 0-indexed
            counts[weekday] = group.cards.count
        }
        return counts
    }

    private var todayWeekdayIndex: Int {
        Calendar.current.component(.weekday, from: Date()) - 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // MARK: - Collapsed Header
            headerRow

            // Day indicator strip — always visible
            WeekDayIndicatorStrip(
                reviewCounts: reviewCountsByWeekday,
                todayIndex: todayWeekdayIndex
            )

            // MARK: - Expanded Content
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .stroke(AppColor.cardBorder)
        )
        .cardShadow()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Weekly review schedule, \(totalCount) reviews this week")
    }

    // MARK: - Header

    private var headerRow: some View {
        Button {
            HapticManager.shared.light()
            withAnimation(AppAnimation.springDefault) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundStyle(AppColor.accent)

                Text("This Week: \(totalCount) review\(totalCount == 1 ? "" : "s")")
                    .font(AppFont.headline)
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(AppAnimation.springDefault, value: isExpanded)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse weekly schedule" : "Expand weekly schedule")
        .accessibilityHint("Shows \(totalCount) upcoming reviews grouped by day")
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            ForEach(weeklyGroups.indices, id: \.self) { groupIndex in
                let group = weeklyGroups[groupIndex]
                daySection(date: group.date, cards: group.cards)
            }
        }
        .padding(.top, AppSpacing.sm)
    }

    private func daySection(date: Date, cards: [(SpacedRepetitionCard, Problem)]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Day header
            Text(dayLabel(for: date))
                .font(AppFont.subheadline)
                .foregroundStyle(AppColor.accent.opacity(0.8))
                .accessibilityAddTraits(.isHeader)

            // Problem list
            ForEach(cards, id: \.0.id) { card, problem in
                NavigationLink(value: problem) {
                    problemRow(problem: problem, card: card)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func problemRow(problem: Problem, card: SpacedRepetitionCard) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Difficulty color accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(problem.difficulty.color)
                .frame(width: 4, height: 28)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(problem.title)
                    .font(AppFont.callout)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("#\(problem.id) · \(problem.topic.rawValue)")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppFont.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, AppSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(problem.title), \(problem.difficulty.rawValue), \(problem.topic.rawValue)")
        .accessibilityHint("Opens problem chat")
    }

    // MARK: - Helpers

    /// Returns a user-friendly label like "Tomorrow", "Wednesday", or "Apr 10"
    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        }
        let formatter = DateFormatter()
        // ⚠️ If within this week, show weekday name; otherwise show short date
        if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE" // "Wednesday"
        } else {
            formatter.dateStyle = .medium
        }
        return formatter.string(from: date)
    }
}
