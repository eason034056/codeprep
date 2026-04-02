import SwiftUI

struct CodeBlockView: View {
    let code: String
    let language: String?
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                if let language = language, !language.isEmpty {
                    Text(language.lowercased())
                        .font(AppFont.caption2)
                        .foregroundStyle(AppColor.codeText.opacity(0.6))
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }

                Spacer()

                Button {
                    UIPasteboard.general.string = code
                    HapticManager.shared.light()
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopied = false
                    }
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                        Text(showCopied ? "Copied" : "Copy")
                            .font(AppFont.caption2)
                    }
                    .foregroundStyle(AppColor.codeText.opacity(0.7))
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .animation(AppAnimation.fadeQuick, value: showCopied)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)

            // Syntax-highlighted code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(SyntaxHighlighter.highlight(code, language: language))
                    .textSelection(.enabled)
                    .lineSpacing(4)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.md)
            }
        }
        .background(AppColor.codeBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
    }
}
