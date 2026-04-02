import Foundation
import SwiftData

final class ProgressRepository: ProgressRepositoryProtocol, @unchecked Sendable {
    private let modelContext: ModelContext
    private let userId: String

    init(modelContext: ModelContext, userId: String) {
        self.modelContext = modelContext
        self.userId = userId
    }

    // MARK: - UserProblemProgress

    func getProgress(for problemId: Int) -> UserProblemProgress? {
        let uid = userId
        let descriptor = FetchDescriptor<SDUserProblemProgress>(
            predicate: #Predicate { $0.problemId == problemId && $0.userId == uid }
        )
        guard let sd = try? modelContext.fetch(descriptor).first else { return nil }
        return ProgressMapper.toDomain(sd)
    }

    func getAllProgress() -> [UserProblemProgress] {
        let uid = userId
        let descriptor = FetchDescriptor<SDUserProblemProgress>(
            predicate: #Predicate { $0.userId == uid },
            sortBy: [SortDescriptor(\.problemId)]
        )
        let results = (try? modelContext.fetch(descriptor)) ?? []
        return results.compactMap { ProgressMapper.toDomain($0) }
    }

    func saveProgress(_ progress: UserProblemProgress) {
        let pid = progress.problemId
        let uid = userId
        let descriptor = FetchDescriptor<SDUserProblemProgress>(
            predicate: #Predicate { $0.problemId == pid && $0.userId == uid }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.statusRaw = progress.status.rawValue
            existing.attemptCount = progress.attemptCount
            existing.lastAttemptDate = progress.lastAttemptDate
            existing.bestApproachConfirmed = progress.bestApproachConfirmed
            existing.umpireSolutionUnlocked = progress.umpireSolutionUnlocked
            existing.notes = progress.notes
            existing.lastModified = Date()
            existing.syncStatus = "pendingUpload"
        } else {
            let sd = ProgressMapper.toSwiftData(progress)
            sd.userId = userId
            sd.lastModified = Date()
            sd.syncStatus = "pendingUpload"
            modelContext.insert(sd)
        }
        try? modelContext.save()
        NotificationCenter.default.post(name: .localDataDidChange, object: nil)
    }

    func updateProgress(problemId: Int, update: (inout UserProblemProgress) -> Void) {
        var progress = getProgress(for: problemId) ?? UserProblemProgress.new(problemId: problemId, userId: userId)
        update(&progress)
        saveProgress(progress)
    }

    // MARK: - SpacedRepetitionCard

    func getCard(for problemId: Int) -> SpacedRepetitionCard? {
        let uid = userId
        let descriptor = FetchDescriptor<SDSpacedRepetitionCard>(
            predicate: #Predicate { $0.problemId == problemId && $0.userId == uid }
        )
        guard let sd = try? modelContext.fetch(descriptor).first else { return nil }
        return ProgressMapper.cardToDomain(sd)
    }

    func getOrCreateCard(for problemId: Int) -> SpacedRepetitionCard {
        if let existing = getCard(for: problemId) {
            return existing
        }
        let card = SpacedRepetitionCard.new(problemId: problemId, userId: userId)
        saveCard(card)
        return card
    }

    func getAllCards() -> [SpacedRepetitionCard] {
        let uid = userId
        let descriptor = FetchDescriptor<SDSpacedRepetitionCard>(
            predicate: #Predicate { $0.userId == uid },
            sortBy: [SortDescriptor(\.nextReviewDate)]
        )
        let results = (try? modelContext.fetch(descriptor)) ?? []
        return results.map { ProgressMapper.cardToDomain($0) }
    }

    func getDueCards(before date: Date) -> [SpacedRepetitionCard] {
        let uid = userId
        let descriptor = FetchDescriptor<SDSpacedRepetitionCard>(
            predicate: #Predicate { $0.nextReviewDate <= date && $0.userId == uid },
            sortBy: [SortDescriptor(\.nextReviewDate)]
        )
        let results = (try? modelContext.fetch(descriptor)) ?? []
        return results.map { ProgressMapper.cardToDomain($0) }
    }

    func saveCard(_ card: SpacedRepetitionCard) {
        let pid = card.problemId
        let uid = userId
        let descriptor = FetchDescriptor<SDSpacedRepetitionCard>(
            predicate: #Predicate { $0.problemId == pid && $0.userId == uid }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.repetitionCount = card.repetitionCount
            existing.interval = card.interval
            existing.easinessFactor = card.easinessFactor
            existing.nextReviewDate = card.nextReviewDate
            existing.lastReviewDate = card.lastReviewDate
            existing.lastQualityRating = card.lastQualityRating
            existing.lastModified = Date()
            existing.syncStatus = "pendingUpload"
        } else {
            let sd = ProgressMapper.cardToSwiftData(card)
            sd.userId = userId
            sd.lastModified = Date()
            sd.syncStatus = "pendingUpload"
            modelContext.insert(sd)
        }
        try? modelContext.save()
        NotificationCenter.default.post(name: .localDataDidChange, object: nil)
    }

    // MARK: - DailyChallenge

    func getDailyChallenge(for date: Date) -> DailyChallenge? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let uid = userId

        let descriptor = FetchDescriptor<SDDailyChallenge>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay && $0.userId == uid }
        )
        guard let sd = try? modelContext.fetch(descriptor).first else { return nil }
        return ProgressMapper.challengeToDomain(sd)
    }

    func saveDailyChallenge(_ challenge: DailyChallenge) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: challenge.date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let uid = userId

        let descriptor = FetchDescriptor<SDDailyChallenge>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay && $0.userId == uid }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.problemIds = challenge.problemIds
            existing.completedProblemIds = Array(challenge.completedProblemIds)
            existing.lastModified = Date()
            existing.syncStatus = "pendingUpload"
        } else {
            let sd = ProgressMapper.challengeToSwiftData(challenge)
            sd.userId = userId
            sd.lastModified = Date()
            sd.syncStatus = "pendingUpload"
            modelContext.insert(sd)
        }
        try? modelContext.save()
        NotificationCenter.default.post(name: .localDataDidChange, object: nil)
    }

    func markProblemCompleted(challengeId: UUID, problemId: Int) {
        let descriptor = FetchDescriptor<SDDailyChallenge>(
            predicate: #Predicate { $0.challengeId == challengeId }
        )
        guard let sd = try? modelContext.fetch(descriptor).first else { return }
        if !sd.completedProblemIds.contains(problemId) {
            sd.completedProblemIds.append(problemId)
        }
        sd.lastModified = Date()
        sd.syncStatus = "pendingUpload"
        try? modelContext.save()
        NotificationCenter.default.post(name: .localDataDidChange, object: nil)
    }

    // MARK: - Gamification

    func getCompletionDates() -> [Date] {
        let allProgress = getAllProgress()
        return allProgress.compactMap { progress in
            guard progress.status == .solvedWithHelp || progress.status == .solvedIndependently else {
                return nil
            }
            return progress.lastAttemptDate
        }
    }

    func getCompletedProblemIds() -> Set<Int> {
        let allProgress = getAllProgress()
        return Set(allProgress.compactMap { progress in
            guard progress.status == .solvedWithHelp || progress.status == .solvedIndependently else {
                return nil
            }
            return progress.problemId
        })
    }
}

extension Notification.Name {
    static let localDataDidChange = Notification.Name("localDataDidChange")
}
