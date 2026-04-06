import SwiftUI

/// A horizontal strip of 7 day indicators showing review volume per day.
///
/// Color intensity reflects how many reviews are due:
/// - 0 cards: `cardBackground` (dim)
/// - 1-2 cards: `accent.opacity(0.5)` (medium)
/// - 3+ cards: `accent` (bright)
/// Today's indicator gets an accent-colored ring.
struct WeekDayIndicatorStrip: View {
    /// Number of reviews due per day, indexed by weekday offset from start of week (0 = Sun/Mon depending on locale).
    let reviewCounts: [Int]

    // 💡 Short weekday labels derived from user's locale
    private static let weekdaySymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        // veryShort gives single letters: S, M, T, W, T, F, S
        return formatter.veryShortWeekdaySymbols
    }()

    /// Index of today within the 7-day array
    private let todayIndex: Int

    init(reviewCounts: [Int], todayIndex: Int) {
        // ⚠️ Ensure we always have exactly 7 entries
        var counts = reviewCounts
        while counts.count < 7 { counts.append(0) }
        self.reviewCounts = Array(counts.prefix(7))
        self.todayIndex = todayIndex
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(0..<7, id: \.self) { index in
                dayIndicator(index: index, count: reviewCounts[index])
            }
        }
    }

    private func dayIndicator(index: Int, count: Int) -> some View {
        VStack(spacing: AppSpacing.xs) {
            // Dot indicator — color reflects review volume
            Circle()
                .fill(dotColor(for: count))
                .frame(width: 12, height: 12)
                .overlay {
                    // 💡 Today gets an accent ring to highlight current day
                    if index == todayIndex {
                        Circle()
                            .stroke(AppColor.accent, lineWidth: 2)
                            .frame(width: 18, height: 18)
                    }
                }
                .frame(width: 20, height: 20) // Fixed hit area

            // Weekday label
            Text(Self.weekdaySymbols[index])
                .font(AppFont.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(index: index, count: count))
    }

    // MARK: - Helpers

    private func dotColor(for count: Int) -> Color {
        switch count {
        case 0: return AppColor.cardBackground
        case 1...2: return AppColor.accent.opacity(0.5)
        default: return AppColor.accent
        }
    }

    private func accessibilityLabel(index: Int, count: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let dayName = formatter.weekdaySymbols[index]
        let isToday = index == todayIndex ? ", today" : ""
        return "\(dayName)\(isToday): \(count) review\(count == 1 ? "" : "s")"
    }
}
