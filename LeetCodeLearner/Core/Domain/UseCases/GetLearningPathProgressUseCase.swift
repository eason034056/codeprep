import Foundation

struct TopicProgress: Identifiable {
    let id: ProblemTopic
    let topic: ProblemTopic
    let totalCount: Int
    let solvedCount: Int
    let attemptedCount: Int

    var progressPercent: Double {
        guard totalCount > 0 else { return 0 }
        return Double(solvedCount) / Double(totalCount)
    }
}

final class GetLearningPathProgressUseCase {
    private let problemRepo: ProblemRepositoryProtocol
    private let progressRepo: ProgressRepositoryProtocol

    init(problemRepo: ProblemRepositoryProtocol, progressRepo: ProgressRepositoryProtocol) {
        self.problemRepo = problemRepo
        self.progressRepo = progressRepo
    }

    func execute(learningPath: LearningPath) -> [TopicProgress] {
        let problems = problemRepo.fetchByLearningPath(learningPath)
        let allProgress = progressRepo.getAllProgress()
        let progressMap = Dictionary(uniqueKeysWithValues: allProgress.map { ($0.problemId, $0) })

        var topicMap: [ProblemTopic: (total: Int, solved: Int, attempted: Int)] = [:]

        for problem in problems {
            var stats = topicMap[problem.topic] ?? (total: 0, solved: 0, attempted: 0)
            stats.total += 1

            if let progress = progressMap[problem.id] {
                switch progress.status {
                case .solvedIndependently, .solvedWithHelp:
                    stats.solved += 1
                case .attempted:
                    stats.attempted += 1
                case .unseen:
                    break
                }
            }
            topicMap[problem.topic] = stats
        }

        return ProblemTopic.allCases.compactMap { topic in
            guard let stats = topicMap[topic] else { return nil }
            return TopicProgress(
                id: topic,
                topic: topic,
                totalCount: stats.total,
                solvedCount: stats.solved,
                attemptedCount: stats.attempted
            )
        }
    }

    func overallProgress(learningPath: LearningPath) -> (solved: Int, total: Int) {
        let problems = problemRepo.fetchByLearningPath(learningPath)
        let allProgress = progressRepo.getAllProgress()
        let progressMap = Dictionary(uniqueKeysWithValues: allProgress.map { ($0.problemId, $0) })

        let solved = problems.filter { problem in
            let status = progressMap[problem.id]?.status ?? .unseen
            return status == .solvedIndependently || status == .solvedWithHelp
        }.count

        return (solved: solved, total: problems.count)
    }
}
