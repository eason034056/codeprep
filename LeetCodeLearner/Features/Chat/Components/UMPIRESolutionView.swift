import SwiftUI

struct UMPIRESolutionView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Header
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(AppColor.success)
                Text("UMPIRE Solution")
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.success)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.success.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))

            // Content
            MarkdownContentView(content, isUser: false)
        }
    }
}
