import Foundation
@testable import LeetCodeLearner

enum TestHelpers {

    static func makeProblem(
        id: Int = 1,
        title: String = "Two Sum",
        difficulty: Difficulty = .easy,
        topic: ProblemTopic = .arraysAndHashing,
        learningPaths: Set<LearningPath> = [.grind75],
        grind75Week: Int? = 1,
        grind75Order: Int? = 1,
        neetcodeOrder: Int? = nil,
        description: String? = nil
    ) -> Problem {
        Problem(
            id: id,
            title: title,
            difficulty: difficulty,
            topic: topic,
            url: URL(string: "https://leetcode.com/problems/\(id)")!,
            learningPaths: learningPaths,
            grind75Week: grind75Week,
            grind75Order: grind75Order,
            neetcodeOrder: neetcodeOrder,
            description: description
        )
    }

    static func makeCard(
        problemId: Int,
        nextReviewDate: Date = Date(),
        interval: Double = 1.0,
        easinessFactor: Double = 2.5,
        repetitionCount: Int = 1
    ) -> SpacedRepetitionCard {
        SpacedRepetitionCard(
            id: UUID(),
            userId: "",
            problemId: problemId,
            repetitionCount: repetitionCount,
            interval: interval,
            easinessFactor: easinessFactor,
            nextReviewDate: nextReviewDate,
            lastReviewDate: nil,
            lastQualityRating: nil
        )
    }

    static func makeProgress(
        problemId: Int,
        status: ProblemStatus = .unseen,
        attemptCount: Int = 0
    ) -> UserProblemProgress {
        UserProblemProgress(
            id: UUID(),
            userId: "",
            problemId: problemId,
            status: status,
            attemptCount: attemptCount,
            lastAttemptDate: nil,
            bestApproachConfirmed: false,
            umpireSolutionUnlocked: false,
            notes: ""
        )
    }
}
