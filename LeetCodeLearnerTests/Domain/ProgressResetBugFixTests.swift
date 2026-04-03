import XCTest
@testable import LeetCodeLearner

/// Tests for the COD-20 bug fix: progress reset after login.
///
/// The bug: DIContainer cached `_homeViewModel` with stale repos after auth state change.
/// The fix: Clear `_homeViewModel = nil` in the auth listener (DIContainer.swift line 111).
///
/// Since AuthManager is a concrete class (not protocol), we test the **observable effects**:
/// - A fresh HomeViewModel with correct repos shows migrated progress
/// - Stale repos (wrong userId) cause zero progress (reproducing the bug)
/// - Factory-created ViewModels (ReviewQueue, LearningPaths) are always fresh
@MainActor
final class ProgressResetBugFixTests: XCTestCase {

    private var problemRepo: MockProblemRepository!
    private var progressRepo: MockProgressRepository!

    override func setUp() {
        super.setUp()
        problemRepo = MockProblemRepository()
        progressRepo = MockProgressRepository()

        // Seed 5 problems for testing
        problemRepo.problems = (1...5).map {
            TestHelpers.makeProblem(id: $0, title: "Problem \($0)", difficulty: .easy)
        }
    }

    // MARK: - HomeViewModel Fresh Instance Tests

    // Test: fresh HomeViewModel with correct repos shows solved count
    func test_freshHomeViewModel_showsCorrectProgress() {
        // GIVEN: User has solved 3 problems (progress stored in repo)
        for id in 1...3 {
            progressRepo.saveProgress(
                TestHelpers.makeProgress(problemId: id, status: .solvedIndependently, attemptCount: 1)
            )
        }
        progressRepo.completedIds = [1, 2, 3]

        let vm = makeHomeViewModel()

        // WHEN: loadDailyProblems is called
        vm.loadDailyProblems()

        // THEN: overallSolved reflects the 3 solved problems
        XCTAssertEqual(vm.overallSolved, 3, "Fresh ViewModel should show all solved problems")
    }

    // Test: fresh HomeViewModel loads correct XP from completed problems
    func test_freshHomeViewModel_showsCorrectXP() {
        // GIVEN: User completed 2 easy problems (10 XP each)
        progressRepo.completedIds = [1, 2]

        let vm = makeHomeViewModel()
        vm.loadDailyProblems()

        // THEN: totalXP = 2 × 10 = 20
        XCTAssertEqual(vm.totalXP, 20, "XP should be sum of completed problem rewards")
    }

    // Test: fresh HomeViewModel loads correct streak
    func test_freshHomeViewModel_showsCorrectStreak() {
        // GIVEN: User has completion dates for today and yesterday (2-day streak)
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        progressRepo.completionDates = [today, yesterday]

        let vm = makeHomeViewModel()
        vm.loadDailyProblems()

        // THEN: streak = 2
        XCTAssertEqual(vm.currentStreak, 2, "Streak should reflect consecutive completion dates")
    }

    // Test: fresh HomeViewModel shows due review cards
    func test_freshHomeViewModel_showsDueReviewCount() {
        // GIVEN: 2 cards are due for review (nextReviewDate in the past)
        let pastDate = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        progressRepo.cards = [
            TestHelpers.makeCard(problemId: 1, nextReviewDate: pastDate),
            TestHelpers.makeCard(problemId: 2, nextReviewDate: pastDate)
        ]

        let vm = makeHomeViewModel()
        vm.loadDailyProblems()

        // THEN: dueReviewCount = 2
        XCTAssertEqual(vm.dueReviewCount, 2, "Due review count should match overdue cards")
    }

    // MARK: - Simulating the Bug (Stale Repos)

    // Test: ViewModel with empty repo shows zero progress (simulates stale cache)
    func test_staleViewModel_emptyRepo_showsZeroProgress() {
        // GIVEN: An empty progressRepo (simulating the stale repo with wrong userId)
        let emptyRepo = MockProgressRepository()
        let vm = HomeViewModel(
            selectDailyUseCase: SelectDailyProblemsUseCase(
                problemRepo: problemRepo, progressRepo: emptyRepo
            ),
            problemRepo: problemRepo,
            progressRepo: emptyRepo,
            learningPathProgress: GetLearningPathProgressUseCase(
                problemRepo: problemRepo, progressRepo: emptyRepo
            )
        )
        vm.learningPath = .grind75

        // WHEN: loadDailyProblems is called
        vm.loadDailyProblems()

        // THEN: Everything is zero — this was the bug symptom
        XCTAssertEqual(vm.overallSolved, 0)
        XCTAssertEqual(vm.totalXP, 0)
        XCTAssertEqual(vm.currentStreak, 0)
    }

    // Test: two different ViewModels with different repos show different data
    // This proves that creating a fresh ViewModel (the fix) resolves the stale data issue
    func test_differentRepos_produceDifferentViewModelState() {
        // GIVEN: "old" repo has no data, "new" repo has progress
        let oldRepo = MockProgressRepository()
        let newRepo = MockProgressRepository()
        for id in 1...3 {
            newRepo.saveProgress(
                TestHelpers.makeProgress(problemId: id, status: .solvedIndependently)
            )
        }
        newRepo.completedIds = [1, 2, 3]

        // WHEN: Create ViewModels with each repo
        let oldVM = HomeViewModel(
            selectDailyUseCase: SelectDailyProblemsUseCase(
                problemRepo: problemRepo, progressRepo: oldRepo
            ),
            problemRepo: problemRepo,
            progressRepo: oldRepo,
            learningPathProgress: GetLearningPathProgressUseCase(
                problemRepo: problemRepo, progressRepo: oldRepo
            )
        )
        oldVM.learningPath = .grind75

        let newVM = HomeViewModel(
            selectDailyUseCase: SelectDailyProblemsUseCase(
                problemRepo: problemRepo, progressRepo: newRepo
            ),
            problemRepo: problemRepo,
            progressRepo: newRepo,
            learningPathProgress: GetLearningPathProgressUseCase(
                problemRepo: problemRepo, progressRepo: newRepo
            )
        )
        newVM.learningPath = .grind75

        oldVM.loadDailyProblems()
        newVM.loadDailyProblems()

        // THEN: Old VM shows zero, new VM shows progress
        XCTAssertEqual(oldVM.overallSolved, 0, "Stale ViewModel should show zero")
        XCTAssertEqual(newVM.overallSolved, 3, "Fresh ViewModel should show migrated data")
        XCTAssertNotEqual(oldVM.totalXP, newVM.totalXP)
    }

    // MARK: - ReviewQueueViewModel (Should Be Unaffected)

    // Test: ReviewQueueViewModel is always fresh (factory-created, never cached)
    func test_reviewQueueViewModel_alwaysFresh() {
        // GIVEN: Due cards in the repo
        let pastDate = Date(timeIntervalSinceNow: -3600)
        progressRepo.cards = [
            TestHelpers.makeCard(problemId: 1, nextReviewDate: pastDate)
        ]

        // WHEN: Create two separate instances (simulating tab switches)
        let vm1 = ReviewQueueViewModel(
            progressRepo: progressRepo,
            problemRepo: problemRepo,
            updateSRUseCase: UpdateSpacedRepetitionUseCase(
                progressRepo: progressRepo, sm2: SM2Algorithm()
            )
        )
        let vm2 = ReviewQueueViewModel(
            progressRepo: progressRepo,
            problemRepo: problemRepo,
            updateSRUseCase: UpdateSpacedRepetitionUseCase(
                progressRepo: progressRepo, sm2: SM2Algorithm()
            )
        )

        vm1.loadDueCards()
        vm2.loadDueCards()

        // THEN: Both instances see the same data (not stale)
        XCTAssertEqual(vm1.dueCards.count, vm2.dueCards.count)
        XCTAssertEqual(vm1.dueCards.count, 1)
    }

    // MARK: - LearningPathsViewModel (Should Be Unaffected)

    // Test: LearningPathsViewModel is always fresh (factory-created, never cached)
    func test_learningPathsViewModel_alwaysFresh() {
        // GIVEN: Progress exists
        progressRepo.saveProgress(
            TestHelpers.makeProgress(problemId: 1, status: .solvedIndependently)
        )

        // WHEN: Create two separate instances
        let useCase = GetLearningPathProgressUseCase(
            problemRepo: problemRepo, progressRepo: progressRepo
        )
        let vm1 = LearningPathsViewModel(progressUseCase: useCase)
        let vm2 = LearningPathsViewModel(progressUseCase: useCase)

        vm1.loadProgress()
        vm2.loadProgress()

        // THEN: Both show the same data
        XCTAssertEqual(vm1.overallSolved, vm2.overallSolved)
    }

    // MARK: - Edge Cases

    // Test: HomeViewModel with zero problems doesn't crash
    func test_homeViewModel_emptyProblemRepo_doesNotCrash() {
        let emptyProblemRepo = MockProblemRepository()
        let vm = HomeViewModel(
            selectDailyUseCase: SelectDailyProblemsUseCase(
                problemRepo: emptyProblemRepo, progressRepo: progressRepo
            ),
            problemRepo: emptyProblemRepo,
            progressRepo: progressRepo,
            learningPathProgress: GetLearningPathProgressUseCase(
                problemRepo: emptyProblemRepo, progressRepo: progressRepo
            )
        )
        vm.learningPath = .grind75

        // Should not crash
        vm.loadDailyProblems()

        XCTAssertEqual(vm.overallSolved, 0)
        XCTAssertEqual(vm.overallTotal, 0)
    }

    // Test: HomeViewModel with mixed difficulty XP calculation
    func test_freshHomeViewModel_mixedDifficultyXP() {
        // GIVEN: Problems of different difficulties
        problemRepo.problems = [
            TestHelpers.makeProblem(id: 1, difficulty: .easy),   // 10 XP
            TestHelpers.makeProblem(id: 2, difficulty: .medium), // 25 XP
            TestHelpers.makeProblem(id: 3, difficulty: .hard),   // 50 XP
        ]
        progressRepo.completedIds = [1, 2, 3]

        let vm = makeHomeViewModel()
        vm.loadDailyProblems()

        // THEN: totalXP = 10 + 25 + 50 = 85
        XCTAssertEqual(vm.totalXP, 85)
    }

    // Test: Milestone celebration triggers at 10 solved
    func test_freshHomeViewModel_milestoneAt10Solved() {
        // GIVEN: 10 problems in repo, all solved
        problemRepo.problems = (1...10).map {
            TestHelpers.makeProblem(id: $0, title: "Problem \($0)")
        }
        for id in 1...10 {
            progressRepo.saveProgress(
                TestHelpers.makeProgress(problemId: id, status: .solvedIndependently)
            )
        }
        progressRepo.completedIds = Set(1...10)

        let vm = makeHomeViewModel()
        vm.loadDailyProblems()

        // THEN: Milestone celebration should trigger
        XCTAssertEqual(vm.overallSolved, 10)
        XCTAssertTrue(vm.showMilestoneCelebration)
        XCTAssertEqual(vm.milestoneMessage, "10 Problems Solved!")
    }

    // MARK: - Helpers

    private func makeHomeViewModel() -> HomeViewModel {
        let vm = HomeViewModel(
            selectDailyUseCase: SelectDailyProblemsUseCase(
                problemRepo: problemRepo, progressRepo: progressRepo
            ),
            problemRepo: problemRepo,
            progressRepo: progressRepo,
            learningPathProgress: GetLearningPathProgressUseCase(
                problemRepo: problemRepo, progressRepo: progressRepo
            )
        )
        vm.learningPath = .grind75
        return vm
    }
}
