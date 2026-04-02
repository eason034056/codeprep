import Foundation
@testable import LeetCodeLearner

final class MockProblemRepository: ProblemRepositoryProtocol, @unchecked Sendable {
    var problems: [Problem] = []

    func fetchAll() -> [Problem] {
        problems
    }

    func fetchByTopic(_ topic: ProblemTopic) -> [Problem] {
        problems.filter { $0.topic == topic }
    }

    func fetchByLearningPath(_ path: LearningPath) -> [Problem] {
        problems.filter { $0.learningPaths.contains(path) }
    }

    func fetchById(_ id: Int) -> Problem? {
        problems.first { $0.id == id }
    }

    func fetchByIds(_ ids: [Int]) -> [Problem] {
        ids.compactMap { id in problems.first { $0.id == id } }
    }

    func seedIfNeeded() {
        // no-op in tests
    }
}
