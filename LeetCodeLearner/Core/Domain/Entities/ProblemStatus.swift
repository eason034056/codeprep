import Foundation

enum ProblemStatus: String, Codable, Sendable {
    case unseen
    case attempted
    case solvedWithHelp
    case solvedIndependently
}
