import Foundation
import SwiftData

@Model
final class SDProblem {
    @Attribute(.unique) var problemId: Int
    var title: String
    var difficultyRaw: String
    var topicRaw: String
    var urlString: String
    var learningPathsRaw: [String]
    var grind75Week: Int?
    var grind75Order: Int?
    var neetcodeOrder: Int?
    var problemDescription: String?

    init(problemId: Int, title: String, difficultyRaw: String, topicRaw: String, urlString: String, learningPathsRaw: [String], grind75Week: Int?, grind75Order: Int?, neetcodeOrder: Int?, problemDescription: String? = nil) {
        self.problemId = problemId
        self.title = title
        self.difficultyRaw = difficultyRaw
        self.topicRaw = topicRaw
        self.urlString = urlString
        self.learningPathsRaw = learningPathsRaw
        self.grind75Week = grind75Week
        self.grind75Order = grind75Order
        self.neetcodeOrder = neetcodeOrder
        self.problemDescription = problemDescription
    }
}
