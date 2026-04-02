import Foundation

enum ProblemMapper {
    static func toDomain(_ sd: SDProblem) -> Problem? {
        guard let difficulty = Difficulty(rawValue: sd.difficultyRaw),
              let topic = ProblemTopic(rawValue: sd.topicRaw),
              let url = URL(string: sd.urlString) else {
            return nil
        }
        let paths = Set(sd.learningPathsRaw.compactMap { LearningPath(rawValue: $0) })
        return Problem(
            id: sd.problemId,
            title: sd.title,
            difficulty: difficulty,
            topic: topic,
            url: url,
            learningPaths: paths,
            grind75Week: sd.grind75Week,
            grind75Order: sd.grind75Order,
            neetcodeOrder: sd.neetcodeOrder,
            description: sd.problemDescription
        )
    }

    static func toSwiftData(_ problem: Problem) -> SDProblem {
        SDProblem(
            problemId: problem.id,
            title: problem.title,
            difficultyRaw: problem.difficulty.rawValue,
            topicRaw: problem.topic.rawValue,
            urlString: problem.url.absoluteString,
            learningPathsRaw: problem.learningPaths.map(\.rawValue),
            grind75Week: problem.grind75Week,
            grind75Order: problem.grind75Order,
            neetcodeOrder: problem.neetcodeOrder,
            problemDescription: problem.description
        )
    }
}
