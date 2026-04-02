import Foundation

enum UMPIREStep: Int, CaseIterable, Codable, Sendable {
    case understand = 0
    case match = 1
    case plan = 2
    case implement = 3
    case review = 4
    case evaluate = 5

    var title: String {
        switch self {
        case .understand: return "U - Understand"
        case .match: return "M - Match"
        case .plan: return "P - Plan"
        case .implement: return "I - Implement"
        case .review: return "R - Review"
        case .evaluate: return "E - Evaluate"
        }
    }

    var description: String {
        switch self {
        case .understand: return "Clarify the problem, inputs, outputs, constraints, and edge cases"
        case .match: return "Identify the problem category, pattern, and relevant techniques"
        case .plan: return "Develop approach with pseudocode and data structure choices"
        case .implement: return "Write clean, interview-ready solution code"
        case .review: return "Trace through code, test with examples, catch bugs"
        case .evaluate: return "Analyze time/space complexity and discuss tradeoffs"
        }
    }

    var letter: String {
        switch self {
        case .understand: return "U"
        case .match: return "M"
        case .plan: return "P"
        case .implement: return "I"
        case .review: return "R"
        case .evaluate: return "E"
        }
    }
}
