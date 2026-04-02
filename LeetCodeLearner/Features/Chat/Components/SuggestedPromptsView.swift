import SwiftUI

struct SuggestedPromptsView: View {
    let prompts: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(prompts, id: \.self) { prompt in
                    Button {
                        HapticManager.shared.light()
                        onSelect(prompt)
                    } label: {
                        Text(prompt)
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.accent)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(AppColor.cardBackground)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppColor.accent.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.scalePress)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
        }
    }
}
