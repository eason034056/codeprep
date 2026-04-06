import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
final class DIContainer: ObservableObject {
    let modelContainer: ModelContainer
    let authManager = AuthManager()

    // Repositories — re-created when userId changes
    private var _progressRepo: ProgressRepository?
    private var _chatRepo: ChatRepository?
    private var _currentUserId: String?

    lazy var problemRepo: ProblemRepositoryProtocol = {
        ProblemRepository(modelContext: modelContainer.mainContext)
    }()

    var progressRepo: ProgressRepositoryProtocol {
        ensureRepos()
        return _progressRepo!
    }

    var chatRepo: ChatRepositoryProtocol {
        ensureRepos()
        return _chatRepo!
    }

    // Sync
    private var _syncService: FirestoreSyncService?
    private var cancellables = Set<AnyCancellable>()

    var syncService: FirestoreSyncService {
        if _syncService == nil {
            _syncService = FirestoreSyncService(modelContainer: modelContainer)
        }
        return _syncService!
    }

    // Infrastructure
    let sm2 = SM2Algorithm()
    let notificationManager = NotificationManager()
    let networkMonitor = NetworkMonitor()
    let apiKeyManager = APIKeyManager.shared

    // Network
    lazy var openRouterService: OpenRouterServiceProtocol = {
        OpenRouterService(apiKeyManager: apiKeyManager)
    }()

    // Use Cases — computed properties so they always use current repos
    var selectDailyProblems: SelectDailyProblemsUseCase {
        SelectDailyProblemsUseCase(problemRepo: problemRepo, progressRepo: progressRepo)
    }

    var updateSpacedRepetition: UpdateSpacedRepetitionUseCase {
        UpdateSpacedRepetitionUseCase(progressRepo: progressRepo, sm2: sm2)
    }

    var sendChatMessage: SendChatMessageUseCase {
        SendChatMessageUseCase(openRouterService: openRouterService, chatRepo: chatRepo)
    }

    var evaluateApproach: EvaluateUserApproachUseCase {
        EvaluateUserApproachUseCase(chatRepo: chatRepo, progressRepo: progressRepo, sm2: sm2)
    }

    var scheduleNotifications: ScheduleNotificationsUseCase {
        ScheduleNotificationsUseCase(notificationManager: notificationManager)
    }

    var learningPathProgress: GetLearningPathProgressUseCase {
        GetLearningPathProgressUseCase(problemRepo: problemRepo, progressRepo: progressRepo)
    }

    // Selected model (from UserDefaults)
    var selectedModel: String {
        UserDefaults.standard.string(forKey: "selectedModel") ?? "anthropic/claude-sonnet-4-20250514"
    }

    var selectedLearningPath: LearningPath {
        if let raw = UserDefaults.standard.string(forKey: "learningPath"),
           let path = LearningPath(rawValue: raw) {
            return path
        }
        return .grind75
    }

    init() {
        do {
            self.modelContainer = try ModelContainerSetup.create()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Seed problem database on first launch
        let repo = ProblemRepository(modelContext: modelContainer.mainContext)
        repo.seedIfNeeded()

        // React to auth state changes — start/stop sync
        authManager.$currentUser
            .map { $0?.userId ?? "" }
            .removeDuplicates()
            .sink { [weak self] newUserId in
                guard let self else { return }
                // Invalidate cached repos so they get recreated with new userId
                self._currentUserId = nil
                self._progressRepo = nil
                self._chatRepo = nil
                self._homeViewModel = nil   // Clear cached ViewModel so it rebuilds with new repos

                if !newUserId.isEmpty {
                    self.syncService.start(userId: newUserId)
                } else {
                    self.syncService.stop()
                }

                self.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Repository Management

    private func ensureRepos() {
        let uid = authManager.userId ?? ""
        if uid != _currentUserId {
            _currentUserId = uid
            _progressRepo = ProgressRepository(
                modelContext: modelContainer.mainContext,
                userId: uid
            )
            _chatRepo = ChatRepository(
                modelContext: modelContainer.mainContext,
                userId: uid
            )

            // Migrate orphaned data on first sign-in
            if !uid.isEmpty {
                migrateOrphanedDataIfNeeded(userId: uid)
                backfillMissingCardsIfNeeded()
            }
        }
    }

    private func migrateOrphanedDataIfNeeded(userId: String) {
        let migrationKey = "didMigrateOrphanedData_\(userId)"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        ModelContainerSetup.migrateOrphanedData(
            context: modelContainer.mainContext,
            toUserId: userId
        )
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    /// Backfill SR cards for solved problems that were completed before COD-26 fix.
    /// Scans all progress with solvedWithHelp/solvedIndependently and creates
    /// missing SpacedRepetitionCards so they enter the review queue.
    private func backfillMissingCardsIfNeeded() {
        guard let repo = _progressRepo else { return }

        let allProgress = repo.getAllProgress()
        for progress in allProgress {
            // 💡 Only backfill for solved problems that have no card yet
            guard progress.status == .solvedWithHelp || progress.status == .solvedIndependently,
                  repo.getCard(for: progress.problemId) == nil else { continue }

            // ⚠️ Use quality 3 (solvedWithHelp) or 4 (solvedIndependently)
            //    to match the same mapping in EvaluateUserApproachUseCase
            let quality = progress.status == .solvedIndependently ? 4 : 3
            var card = repo.getOrCreateCard(for: progress.problemId)
            card = sm2.update(card: card, quality: quality)
            repo.saveCard(card)
        }
    }

    // MARK: - ViewModel Factories

    private var _homeViewModel: HomeViewModel?

    var homeViewModel: HomeViewModel {
        if let existing = _homeViewModel { return existing }
        let vm = HomeViewModel(
            selectDailyUseCase: selectDailyProblems,
            problemRepo: problemRepo,
            progressRepo: progressRepo,
            learningPathProgress: learningPathProgress
        )
        vm.learningPath = selectedLearningPath
        vm.loadDailyProblems()  // ⚠️ Pre-load so data is ready even if .onAppear doesn't re-fire after auth
        _homeViewModel = vm
        return vm
    }

    func makeHomeViewModel() -> HomeViewModel {
        homeViewModel
    }

    func makeChatViewModel(for problem: Problem) -> ChatViewModel {
        ChatViewModel(
            problem: problem,
            sendChatUseCase: sendChatMessage,
            evaluateUseCase: evaluateApproach,
            chatRepo: chatRepo,
            model: selectedModel
        )
    }

    func makeReviewQueueViewModel() -> ReviewQueueViewModel {
        ReviewQueueViewModel(
            progressRepo: progressRepo,
            problemRepo: problemRepo,
            updateSRUseCase: updateSpacedRepetition
        )
    }

    func makeLearningPathsViewModel() -> LearningPathsViewModel {
        LearningPathsViewModel(progressUseCase: learningPathProgress)
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        let vm = SettingsViewModel(apiKeyManager: apiKeyManager, authManager: authManager)
        vm.modelContainer = modelContainer
        return vm
    }
}
