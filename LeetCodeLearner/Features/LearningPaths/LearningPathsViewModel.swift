import Foundation
import SwiftUI

@MainActor
final class LearningPathsViewModel: ObservableObject {
    @Published var selectedPath: LearningPath = .grind75
    @Published var topicProgress: [TopicProgress] = []
    @Published var overallSolved: Int = 0
    @Published var overallTotal: Int = 0

    private let progressUseCase: GetLearningPathProgressUseCase

    init(progressUseCase: GetLearningPathProgressUseCase) {
        self.progressUseCase = progressUseCase
    }

    func loadProgress() {
        topicProgress = progressUseCase.execute(learningPath: selectedPath)
        let overall = progressUseCase.overallProgress(learningPath: selectedPath)
        overallSolved = overall.solved
        overallTotal = overall.total
    }
}
