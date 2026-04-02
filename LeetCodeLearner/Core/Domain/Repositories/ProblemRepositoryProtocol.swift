import Foundation

protocol ProblemRepositoryProtocol: Sendable {
    func fetchAll() -> [Problem]
    func fetchByTopic(_ topic: ProblemTopic) -> [Problem]
    func fetchByLearningPath(_ path: LearningPath) -> [Problem]
    func fetchById(_ id: Int) -> Problem?
    func fetchByIds(_ ids: [Int]) -> [Problem]
    func seedIfNeeded()
}
