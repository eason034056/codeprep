import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isUser: Bool { message.role == .user }

    var body: some View {
        if isUser {
            VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Spacer(minLength: 60)

                    MarkdownContentView(message.content, isUser: true)
                        .padding(AppSpacing.md)
                        .background(AppColor.userBubbleGradient)
                        .foregroundStyle(.white)
                        .clipShape(bubbleShape)
                        .cardShadow()
                }

                Text(message.timestamp, style: .time)
                    .font(AppFont.caption2)
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
        } else {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                // Cat tutor avatar
                Image(systemName: "cat.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppColor.accent)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    if message.umpireStep != nil {
                        UMPIRESolutionView(content: message.content)
                    } else {
                        MarkdownContentView(message.content, isUser: false)
                    }

                    Text(message.timestamp, style: .time)
                        .font(AppFont.caption2)
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
            }
            .padding(AppSpacing.md)
            .foregroundStyle(.primary)
        }
    }

    // MARK: - Bubble Background

    @ViewBuilder
    private var bubbleBackground: some View {
        if isUser {
            AppColor.userBubbleGradient
        } else {
            AppColor.assistantBubble
        }
    }

    // MARK: - Bubble Shape

    private var bubbleShape: UnevenRoundedRectangle {
        if isUser {
            UnevenRoundedRectangle(
                topLeadingRadius: AppRadius.large,
                bottomLeadingRadius: AppRadius.large,
                bottomTrailingRadius: AppSpacing.xs,
                topTrailingRadius: AppRadius.large
            )
        } else {
            UnevenRoundedRectangle(
                topLeadingRadius: AppRadius.large,
                bottomLeadingRadius: AppSpacing.xs,
                bottomTrailingRadius: AppRadius.large,
                topTrailingRadius: AppRadius.large
            )
        }
    }
}
