import Foundation

final class SelectDailyProblemsUseCase {
    private let problemRepo: ProblemRepositoryProtocol
    private let progressRepo: ProgressRepositoryProtocol

    init(problemRepo: ProblemRepositoryProtocol, progressRepo: ProgressRepositoryProtocol) {
        self.problemRepo = problemRepo
        self.progressRepo = progressRepo
    }

    func execute(learningPath: LearningPath, date: Date = Date(), excluding: Set<Int> = []) -> DailyChallenge {
        // Check if we already have a challenge for today
        if let existing = progressRepo.getDailyChallenge(for: date) {
            return existing
        }

        let allProblems = problemRepo.fetchByLearningPath(learningPath)
        let allProgress = progressRepo.getAllProgress()
        let progressMap = Dictionary(uniqueKeysWithValues: allProgress.map { ($0.problemId, $0) })
        var selectedIds: [Int] = []

        // Slot 1: Most overdue SR card
        let dueCards = progressRepo.getDueCards(before: date)
            .sorted { card1, card2 in
                // Most overdue first
                card1.nextReviewDate < card2.nextReviewDate
            }

        if let topDue = dueCards.first(where: { !selectedIds.contains($0.problemId) && !excluding.contains($0.problemId) }) {
            selectedIds.append(topDue.problemId)
        }

        // Slot 2: Next in learning path sequence
        let nextInPath = findNextInLearningPath(
            problems: allProblems,
            progressMap: progressMap,
            learningPath: learningPath,
            excluding: Set(selectedIds).union(excluding)
        )
        if let next = nextInPath {
            selectedIds.append(next.id)
        }

        // Slot 3: Weakest topic problem
        let weakTopicProblem = findWeakestTopicProblem(
            problems: allProblems,
            progressMap: progressMap,
            excluding: Set(selectedIds).union(excluding)
        )
        if let weak = weakTopicProblem {
            selectedIds.append(weak.id)
        }

        // Fill remaining slots if needed
        while selectedIds.count < 3 {
            let skip = Set(selectedIds).union(excluding)
            if let unseen = allProblems.first(where: {
                !skip.contains($0.id) &&
                (progressMap[$0.id]?.status ?? .unseen) == .unseen
            }) {
                selectedIds.append(unseen.id)
            } else if let overdue = dueCards.first(where: { !skip.contains($0.problemId) }) {
                selectedIds.append(overdue.problemId)
            } else {
                // All problems done and no due cards - just pick any remaining
                if let any = allProblems.first(where: { !skip.contains($0.id) }) {
                    selectedIds.append(any.id)
                } else {
                    break
                }
            }
        }

        let challenge = DailyChallenge(
            date: Calendar.current.startOfDay(for: date),
            problemIds: selectedIds
        )
        progressRepo.saveDailyChallenge(challenge)
        return challenge
    }

    private func findNextInLearningPath(
        problems: [Problem],
        progressMap: [Int: UserProblemProgress],
        learningPath: LearningPath,
        excluding: Set<Int>
    ) -> Problem? {
        let sorted: [Problem]

        switch learningPath {
        case .grind75:
            sorted = problems
                .filter { $0.grind75Week != nil && $0.grind75Order != nil }
                .sorted { a, b in
                    if a.grind75Week! != b.grind75Week! {
                        return a.grind75Week! < b.grind75Week!
                    }
                    return a.grind75Order! < b.grind75Order!
                }
        case .neetcode150:
            sorted = problems
                .filter { $0.neetcodeOrder != nil }
                .sorted { ($0.neetcodeOrder ?? 0) < ($1.neetcodeOrder ?? 0) }
        }

        return sorted.first { problem in
            !excluding.contains(problem.id) &&
            (progressMap[problem.id]?.status ?? .unseen) != .solvedIndependently
        }
    }

    private func findWeakestTopicProblem(
        problems: [Problem],
        progressMap: [Int: UserProblemProgress],
        excluding: Set<Int>
    ) -> Problem? {
        // Calculate per-topic success rate
        var topicStats: [ProblemTopic: (attempted: Int, solved: Int)] = [:]

        for problem in problems {
            let progress = progressMap[problem.id]
            let status = progress?.status ?? .unseen

            var stats = topicStats[problem.topic] ?? (attempted: 0, solved: 0)
            if status != .unseen {
                stats.attempted += 1
                if status == .solvedIndependently {
                    stats.solved += 1
                }
            }
            topicStats[problem.topic] = stats
        }

        // Find topic with lowest success rate (min 2 attempts to qualify)
        let weakestTopic = topicStats
            .filter { $0.value.attempted >= 2 }
            .min { a, b in
                let rateA = Double(a.value.solved) / Double(a.value.attempted)
                let rateB = Double(b.value.solved) / Double(b.value.attempted)
                return rateA < rateB
            }?.key

        // If we have a weakest topic, pick an unseen problem from it
        if let topic = weakestTopic {
            let topicProblems = problems.filter { $0.topic == topic }
            if let unseen = topicProblems.first(where: {
                !excluding.contains($0.id) &&
                (progressMap[$0.id]?.status ?? .unseen) == .unseen
            }) {
                return unseen
            }
        }

        // Fallback: pick unseen problem from a topic not yet represented
        let selectedTopics = Set(problems.filter { excluding.contains($0.id) }.map(\.topic))
        return problems.first { problem in
            !excluding.contains(problem.id) &&
            !selectedTopics.contains(problem.topic) &&
            (progressMap[problem.id]?.status ?? .unseen) == .unseen
        }
    }
}
