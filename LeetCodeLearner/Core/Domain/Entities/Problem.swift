import Foundation

struct Problem: Identifiable, Hashable, Sendable {
    let id: Int  // LeetCode problem number
    let title: String
    let difficulty: Difficulty
    let topic: ProblemTopic
    let url: URL
    let learningPaths: Set<LearningPath>
    let grind75Week: Int?
    let grind75Order: Int?
    let neetcodeOrder: Int?
    let description: String?

    init(id: Int, title: String, difficulty: Difficulty, topic: ProblemTopic, url: URL, learningPaths: Set<LearningPath>, grind75Week: Int?, grind75Order: Int?, neetcodeOrder: Int?, description: String? = nil) {
        self.id = id
        self.title = title
        self.difficulty = difficulty
        self.topic = topic
        self.url = url
        self.learningPaths = learningPaths
        self.grind75Week = grind75Week
        self.grind75Order = grind75Order
        self.neetcodeOrder = neetcodeOrder
        self.description = description
    }
}
