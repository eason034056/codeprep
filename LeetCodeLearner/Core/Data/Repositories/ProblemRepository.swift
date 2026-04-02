import Foundation
import SwiftData

final class ProblemRepository: ProblemRepositoryProtocol, @unchecked Sendable {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() -> [Problem] {
        let descriptor = FetchDescriptor<SDProblem>(
            sortBy: [SortDescriptor(\.problemId)]
        )
        let results = (try? modelContext.fetch(descriptor)) ?? []
        return results.compactMap { ProblemMapper.toDomain($0) }
    }

    func fetchByTopic(_ topic: ProblemTopic) -> [Problem] {
        let topicRaw = topic.rawValue
        let descriptor = FetchDescriptor<SDProblem>(
            predicate: #Predicate { $0.topicRaw == topicRaw },
            sortBy: [SortDescriptor(\.problemId)]
        )
        let results = (try? modelContext.fetch(descriptor)) ?? []
        return results.compactMap { ProblemMapper.toDomain($0) }
    }

    func fetchByLearningPath(_ path: LearningPath) -> [Problem] {
        // SwiftData #Predicate .contains on arrays crashes at runtime,
        // so fetch all and filter in-memory
        return fetchAll().filter { $0.learningPaths.contains(path) }
    }

    func fetchById(_ id: Int) -> Problem? {
        let descriptor = FetchDescriptor<SDProblem>(
            predicate: #Predicate { $0.problemId == id }
        )
        guard let sd = try? modelContext.fetch(descriptor).first else { return nil }
        return ProblemMapper.toDomain(sd)
    }

    func fetchByIds(_ ids: [Int]) -> [Problem] {
        // SwiftData predicate doesn't support .contains on parameter arrays well,
        // so fetch all and filter
        let allProblems = fetchAll()
        let idSet = Set(ids)
        return allProblems.filter { idSet.contains($0.id) }
    }

    func seedIfNeeded() {
        let descriptor = FetchDescriptor<SDProblem>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        for problem in ProblemSeedData.allProblems {
            let sd = ProblemMapper.toSwiftData(problem)
            modelContext.insert(sd)
        }
        try? modelContext.save()
    }
}
