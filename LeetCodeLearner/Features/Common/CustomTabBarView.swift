import SwiftUI

struct CustomTabBarView: View {
    @Binding var selectedTab: Int
    let namespace: Namespace.ID

    private let tabs: [(icon: String, label: String)] = [
        ("calendar", "Today"),
        ("book.fill", "Learn"),
        ("brain.head.profile", "Review"),
        ("gear", "Settings")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    withAnimation(AppAnimation.springDefault) {
                        selectedTab = index
                    }
                    HapticManager.shared.selection()
                } label: {
                    VStack(spacing: AppSpacing.xs) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: selectedTab == index ? .semibold : .regular))
                            .scaleEffect(selectedTab == index ? 1.1 : 1.0)

                        Text(tab.label)
                            .font(AppFont.caption2)
                            .fontWeight(selectedTab == index ? .semibold : .regular)
                    }
                    .foregroundStyle(selectedTab == index ? AppColor.accent : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                    .background {
                        if selectedTab == index {
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .fill(AppColor.accent.opacity(0.1))
                                .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tab.label) tab")
                .accessibilityAddTraits(selectedTab == index ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.sm)
        .background(AppColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
        .cardShadow()
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.xs)
        .accessibilityAddTraits(.isTabBar)
    }
}
