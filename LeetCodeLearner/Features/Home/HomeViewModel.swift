import Foundation
import SwiftUI
import StoreKit

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var dailyChallenge: DailyChallenge?
    @Published var dailyProblems: [Problem] = []
    @Published var dueReviewCount: Int = 0
    @Published var overallSolved: Int = 0
    @Published var overallTotal: Int = 0

    // Gamification
    @Published var currentStreak: Int = 0
    @Published var totalXP: Int = 0
    @Published var showMilestoneCelebration: Bool = false
    @Published var milestoneMessage: String = ""

    private let selectDailyUseCase: SelectDailyProblemsUseCase
    private let problemRepo: ProblemRepositoryProtocol
    private let progressRepo: ProgressRepositoryProtocol
    private let learningPathProgress: GetLearningPathProgressUseCase

    var learningPath: LearningPath = .grind75

    init(
        selectDailyUseCase: SelectDailyProblemsUseCase,
        problemRepo: ProblemRepositoryProtocol,
        progressRepo: ProgressRepositoryProtocol,
        learningPathProgress: GetLearningPathProgressUseCase
    ) {
        self.selectDailyUseCase = selectDailyUseCase
        self.problemRepo = problemRepo
        self.progressRepo = progressRepo
        self.learningPathProgress = learningPathProgress
    }

    func loadDailyProblems() {
        let challenge = selectDailyUseCase.execute(learningPath: learningPath)
        self.dailyChallenge = challenge
        self.dailyProblems = problemRepo.fetchByIds(challenge.problemIds)
        self.dueReviewCount = progressRepo.getDueCards(before: Date()).count

        let progress = learningPathProgress.overallProgress(learningPath: learningPath)
        let previousSolved = self.overallSolved
        self.overallSolved = progress.solved
        self.overallTotal = progress.total

        // Load gamification
        loadStreak()
        loadXP()

        // Check milestones
        checkMilestones(previousSolved: previousSolved)
    }

    func isProblemCompleted(_ problemId: Int) -> Bool {
        dailyChallenge?.completedProblemIds.contains(problemId) ?? false
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5...11: return "Good morning."
        case 12...16: return "Good afternoon."
        case 17...21: return "Good evening."
        default: return "Good night."
        }
    }

    var playerLevel: PlayerLevel { LevelSystem.level(for: totalXP) }
    var levelProgress: Double { LevelSystem.progressToNextLevel(xp: totalXP) }
    var xpToNextLevel: Int { LevelSystem.xpToNextLevel(xp: totalXP) }

    func xpReward(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 10
        case .medium: return 25
        case .hard: return 50
        }
    }

    // MARK: - Gamification

    private func loadStreak() {
        let dates = progressRepo.getCompletionDates()
        currentStreak = StreakCalculator.calculateStreak(from: dates)
    }

    private func loadXP() {
        let completedIds = progressRepo.getCompletedProblemIds()
        var xp = 0
        for id in completedIds {
            if let problem = problemRepo.fetchById(id) {
                switch problem.difficulty {
                case .easy: xp += 10
                case .medium: xp += 25
                case .hard: xp += 50
                }
            }
        }
        totalXP = xp
    }

    private func checkMilestones(previousSolved: Int) {
        // Every 10 problems solved
        let prevTens = previousSolved / 10
        let currentTens = overallSolved / 10
        if currentTens > prevTens && overallSolved > 0 {
            milestoneMessage = "\(overallSolved) Problems Solved!"
            showMilestoneCelebration = true
            requestAppReviewIfAppropriate()
            return
        }

        // Streak milestones
        if currentStreak == 7 || currentStreak == 30 || currentStreak == 100 {
            milestoneMessage = "\(currentStreak) Day Streak!"
            showMilestoneCelebration = true
            requestAppReviewIfAppropriate()
        }
    }

    private func requestAppReviewIfAppropriate() {
        // Only prompt at meaningful milestones: 10 problems, 7-day streak, or level up
        let hasEnoughProgress = overallSolved >= 10 || currentStreak >= 7
        guard hasEnoughProgress else { return }

        // Throttle: only ask once per 60 days
        let lastPromptKey = "lastReviewPromptDate"
        if let lastPrompt = UserDefaults.standard.object(forKey: lastPromptKey) as? Date,
           Date().timeIntervalSince(lastPrompt) < 60 * 24 * 3600 {
            return
        }

        UserDefaults.standard.set(Date(), forKey: lastPromptKey)

        // Delay slightly so the milestone celebration shows first
        Task {
            try? await Task.sleep(for: .seconds(2))
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
}
