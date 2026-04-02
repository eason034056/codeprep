import SwiftUI

struct MarkdownContentView: View {
    let content: String
    let isUserMessage: Bool
    private let parsedBlocks: [ContentBlock]

    init(_ content: String, isUser: Bool = false) {
        self.content = content
        self.isUserMessage = isUser
        self.parsedBlocks = Self.parseContent(content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ForEach(Array(parsedBlocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let markdown):
                    Text(makeAttributedString(markdown))
                        .textSelection(.enabled)
                        .font(AppFont.body)
                case .code(let code, let language):
                    CodeBlockView(code: code, language: language)
                }
            }
        }
    }

    // MARK: - Parsing

    enum ContentBlock {
        case text(String)
        case code(String, String?)
    }

    private static func parseContent(_ content: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        let pattern = "```(\\w*)\n([\\s\\S]*?)(?:```|$)"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(content)]
        }

        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        var lastEnd = 0
        for match in matches {
            let matchRange = match.range
            // Text before this code block
            if matchRange.location > lastEnd {
                let textRange = NSRange(location: lastEnd, length: matchRange.location - lastEnd)
                let text = nsContent.substring(with: textRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    blocks.append(.text(text))
                }
            }

            // Code block
            let language = match.range(at: 1).length > 0
                ? nsContent.substring(with: match.range(at: 1))
                : nil
            let code = nsContent.substring(with: match.range(at: 2))
                .trimmingCharacters(in: .newlines)

            blocks.append(.code(code, language))
            lastEnd = matchRange.location + matchRange.length
        }

        // Remaining text after last code block
        if lastEnd < nsContent.length {
            let text = nsContent.substring(from: lastEnd).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.text(text))
            }
        }

        if blocks.isEmpty {
            blocks.append(.text(content))
        }

        return blocks
    }

    // MARK: - Attributed String

    private func makeAttributedString(_ markdown: String) -> AttributedString {
        do {
            var attributed = try AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            // Apply inline code styling
            for run in attributed.runs {
                if run.inlinePresentationIntent?.contains(.code) == true {
                    let range = run.range
                    attributed[range].font = AppFont.codeInline
                    if !isUserMessage {
                        attributed[range].backgroundColor = AppColor.assistantBubble
                    }
                }
            }
            return attributed
        } catch {
            return AttributedString(markdown)
        }
    }
}
