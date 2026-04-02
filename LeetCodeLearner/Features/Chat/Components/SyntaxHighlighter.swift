import SwiftUI

enum SyntaxHighlighter {

    static func highlight(_ code: String, language: String?) -> AttributedString {
        var result = AttributedString(code)
        let lang = (language ?? "").lowercased()

        // Apply base styling
        result.font = AppFont.codeBlock
        result.foregroundColor = UIColor(AppColor.codeText)

        // Comments
        applyPattern(to: &result, in: code, pattern: commentPattern(for: lang), color: AppColor.codeComment)

        // Strings (double and single quoted)
        applyPattern(to: &result, in: code, pattern: #"\"(?:[^\"\\]|\\.)*\""#, color: AppColor.codeString)
        applyPattern(to: &result, in: code, pattern: #"'(?:[^'\\]|\\.)*'"#, color: AppColor.codeString)

        // Numbers
        applyPattern(to: &result, in: code, pattern: #"\b\d+\.?\d*\b"#, color: AppColor.codeNumber)

        // Keywords
        let keywords = keywords(for: lang)
        if !keywords.isEmpty {
            let keywordPattern = "\\b(" + keywords.joined(separator: "|") + ")\\b"
            applyPattern(to: &result, in: code, pattern: keywordPattern, color: AppColor.codeKeyword)
        }

        // Built-in functions/types
        let builtins = builtins(for: lang)
        if !builtins.isEmpty {
            let builtinPattern = "\\b(" + builtins.joined(separator: "|") + ")\\b"
            applyPattern(to: &result, in: code, pattern: builtinPattern, color: AppColor.codeBuiltin)
        }

        // Type-like identifiers (capitalized words)
        applyPattern(to: &result, in: code, pattern: #"\b[A-Z][a-zA-Z0-9]*\b"#, color: AppColor.codeType)

        return result
    }

    // MARK: - Private

    private static func applyPattern(to attributed: inout AttributedString, in code: String, pattern: String, color: Color) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let nsCode = code as NSString
        let matches = regex.matches(in: code, range: NSRange(location: 0, length: nsCode.length))

        for match in matches {
            guard let swiftRange = Range(match.range, in: code) else { continue }
            let attrRange = AttributedString.Index(swiftRange.lowerBound, within: attributed)
            let attrEnd = AttributedString.Index(swiftRange.upperBound, within: attributed)
            guard let start = attrRange, let end = attrEnd else { continue }
            attributed[start..<end].foregroundColor = UIColor(color)
        }
    }

    private static func commentPattern(for lang: String) -> String {
        switch lang {
        case "python":
            return #"#.*$"#
        case "swift", "java", "javascript", "typescript", "c", "cpp", "go", "rust", "kotlin":
            return #"//.*$|/\*[\s\S]*?\*/"#
        default:
            return #"//.*$|#.*$|/\*[\s\S]*?\*/"#
        }
    }

    private static func keywords(for lang: String) -> [String] {
        switch lang {
        case "python":
            return ["def", "class", "return", "if", "elif", "else", "for", "while", "in", "not",
                    "and", "or", "is", "import", "from", "as", "try", "except", "finally",
                    "with", "lambda", "yield", "pass", "break", "continue", "raise", "True",
                    "False", "None", "self", "async", "await"]
        case "swift":
            return ["func", "class", "struct", "enum", "protocol", "var", "let", "return",
                    "if", "else", "guard", "switch", "case", "for", "while", "in", "import",
                    "self", "Self", "true", "false", "nil", "throw", "throws", "try", "catch",
                    "async", "await", "private", "public", "static", "override", "init", "deinit"]
        case "java", "kotlin":
            return ["class", "public", "private", "protected", "static", "void", "return",
                    "if", "else", "for", "while", "new", "this", "super", "import", "package",
                    "try", "catch", "finally", "throw", "throws", "interface", "extends",
                    "implements", "abstract", "final", "true", "false", "null", "int", "long",
                    "double", "float", "boolean", "char", "String", "override", "val", "var", "fun", "when"]
        case "javascript", "typescript":
            return ["function", "const", "let", "var", "return", "if", "else", "for", "while",
                    "class", "new", "this", "import", "export", "from", "default", "try",
                    "catch", "finally", "throw", "async", "await", "true", "false", "null",
                    "undefined", "typeof", "instanceof", "switch", "case", "break", "continue",
                    "interface", "type", "enum"]
        case "go":
            return ["func", "package", "import", "return", "if", "else", "for", "range",
                    "switch", "case", "var", "const", "type", "struct", "interface", "map",
                    "chan", "go", "defer", "select", "true", "false", "nil", "break", "continue"]
        case "c", "cpp":
            return ["int", "char", "float", "double", "void", "return", "if", "else", "for",
                    "while", "switch", "case", "break", "continue", "struct", "class", "public",
                    "private", "protected", "virtual", "override", "const", "static", "include",
                    "define", "typedef", "enum", "namespace", "using", "template", "auto",
                    "true", "false", "nullptr", "NULL", "new", "delete", "throw", "try", "catch"]
        default:
            // Generic keywords for unknown languages
            return ["def", "func", "function", "class", "return", "if", "else", "for", "while",
                    "import", "from", "var", "let", "const", "true", "false", "null", "nil",
                    "new", "this", "self", "try", "catch", "throw", "async", "await"]
        }
    }

    private static func builtins(for lang: String) -> [String] {
        switch lang {
        case "python":
            return ["print", "len", "range", "enumerate", "zip", "map", "filter", "sorted",
                    "list", "dict", "set", "tuple", "str", "int", "float", "bool", "type",
                    "isinstance", "hasattr", "getattr", "setattr", "super", "input", "open",
                    "min", "max", "sum", "abs", "any", "all", "reversed", "append"]
        case "javascript", "typescript":
            return ["console", "log", "parseInt", "parseFloat", "Math", "Array", "Object",
                    "Map", "Set", "Promise", "JSON", "fetch", "setTimeout", "setInterval",
                    "push", "pop", "shift", "unshift", "slice", "splice", "forEach",
                    "map", "filter", "reduce", "find", "includes", "indexOf", "join", "split"]
        default:
            return []
        }
    }
}
