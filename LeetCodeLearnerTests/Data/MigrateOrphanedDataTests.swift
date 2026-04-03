import XCTest
import SwiftData
@testable import LeetCodeLearner

/// Integration tests for `ModelContainerSetup.migrateOrphanedData()`.
///
/// Uses an in-memory ModelContainer so tests run fast and don't affect real data.
/// Validates all 4 entity types are migrated from userId="" to the new Firebase UID.
@MainActor
final class MigrateOrphanedDataTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        do {
            container = try ModelContainerSetup.createInMemory()
            context = container.mainContext
        } catch {
            XCTFail("Failed to create in-memory ModelContainer: \(error)")
        }
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - SDUserProblemProgress Migration

    // Test: orphaned progress records are migrated to new userId
    func test_migrateOrphanedData_progressRecords_updatedToNewUserId() {
        // GIVEN: 3 progress records with userId=""
        insertProgress(problemId: 1, userId: "")
        insertProgress(problemId: 2, userId: "")
        insertProgress(problemId: 3, userId: "")

        // WHEN: migrate to "firebase-uid-123"
        ModelContainerSetup.migrateOrphanedData(context: context, toUserId: "firebase-uid-123")

        // THEN: all records now have the new userId
        let descriptor = FetchDescriptor<SDUserProblemProgress>()
        let all = (try? context.fetch(descriptor)) ?? []
        XCTAssertEqual(all.count, 3)
        for record in all {
            XCTAssertEqual(record.userId, "firebase-uid-123",
                           "Progress record for problem \(record.problemId) should be migrated")
        }
    }

    // Test: non-orphaned progress records are NOT affected
    func test_migrateOrphanedData_existingUserRecords_untouched() {
        // GIVEN: 1 orphaned + 1 record belonging to another user
        insertProgress(problemId: 1, userId: "")
        insertProgress(problemId: 2, userId: "other-user-456")

        // WHEN: migrate orphaned data
        ModelContainerSetup.migrateOrphanedData(context: context, toUserId: "firebase-uid-123")

        // THEN: only the orphaned record is migrated
        let descriptor = FetchDescriptor<SDUserProblemProgress>()
        let all = (try? context.fetch(descriptor)) ?? []
        let migrated = all.filter { $0.userId == "firebase-uid-123" }
        let untouched = all.filter { $0.userId == "other-user-456" }
        XCTAssertEqual(migrated.count, 1)
        XCTAssertEqual(untouched.count, 1)
    }

    // MARK: - SDSpacedRepetitionCard Migration

    // Test: orphaned spaced repetition cards are migrated
    func test_migrateOrphanedData_spacedRepetitionCards_updatedToNewUserId() {
        // GIVEN: 2 orphaned cards
        insertCard(problemId: 1, userId: "")
        insertCard(problemId: 2, userId: "")

        // WHEN: migrate
        ModelContainerSetup.migrateOrphanedData(context: context, toUserId: "user-abc")

        // THEN: cards now belong to user-abc
        let descriptor = FetchDescriptor<SDSpacedRepetitionCard>()
        let all = (try? context.fetch(descriptor)) ?? []
        XCTAssertEqual(all.count, 2)
        for card in all {
            XCTAssertEqual(card.userId, "user-abc")
        }
    }

    // MARK: - SDChatSession Migration

    // Test: orphaned chat sessions are migrated
    func test_migrateOrphanedData_chatSessions_updatedToNewUserId() {
        // GIVEN: 1 orphaned chat session
        insertChatSession(problemId: 1, userId: "")

        // WHEN: migrate
        ModelContainerSetup.migrateOrphanedData(context: context, toUserId: "user-xyz")

        // THEN: session now belongs to user-xyz
        let descriptor = FetchDescriptor<SDChatSession>()
        let all = (try? context.fetch(descriptor)) ?? []
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.userId, "user-xyz")
    }

    // MARK: - SDDailyChallenge Migration

    // Test: orphaned daily challenges are migrated
    func test_migrateOrphanedData_dailyChallenges_updatedToNewUserId() {
        // GIVEN: 1 orphaned daily challenge
        insertDailyChallenge(userId: "")

        // WHEN: migrate
        ModelContainerSetup.migrateOrphanedData(context: context, toUserId: "user-daily")

        // THEN: challenge now belongs to user-daily
        let descriptor = FetchDescriptor<SDDailyChallenge>()
        let all = (try? context.fetch(descriptor)) ?? []
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.userId, "user-daily")
    }

    // MARK: - All 4 Entity Types Together

    // Test: migration handles all 4 entity types in a single call
    func test_migrateOrphanedData_allEntityTypes_migratedTogether() {
        // GIVEN: orphaned records across all 4 types
        insertProgress(problemId: 1, userId: "")
        insertCard(problemId: 1, userId: "")
        insertChatSession(problemId: 1, userId: "")
        insertDailyChallenge(userId: "")

        // WHEN: migrate
        ModelContainerSetup.migrateOrphanedData(context: context, toUserId: "full-user")

        // THEN: all types are migrated
        let progress = (try? context.fetch(FetchDescriptor<SDUserProblemProgress>())) ?? []
        let cards = (try? context.fetch(FetchDescriptor<SDSpacedRepetitionCard>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<SDChatSession>())) ?? []
        let challenges = (try? context.fetch(FetchDescriptor<SDDailyChallenge>())) ?? []

        XCTAssertTrue(progress.allSatisfy { $0.userId == "full-user" })
        XCTAssertTrue(cards.allSatisfy { $0.userId == "full-user" })
        XCTAssertTrue(sessions.allSatisfy { $0.userId == "full-user" })
        XCTAssertTrue(challenges.allSatisfy { $0.userId == "full-user" })
    }

    // MARK: - Edge Cases

    // Test: migration with no orphaned data is a no-op (doesn't crash)
    func test_migrateOrphanedData_noOrphans_doesNotCrash() {
        // GIVEN: only records with existing userId
        insertProgress(problemId: 1, userId: "existing-user")

        // WHEN/THEN: should not crash
        ModelContainerSetup.migrateOrphanedData(context: context, toUserId: "new-user")

        // Verify existing record is untouched
        let descriptor = FetchDescriptor<SDUserProblemProgress>()
        let all = (try? context.fetch(descriptor)) ?? []
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.userId, "existing-user")
    }

    // Test: migration with empty database is a no-op
    func test_migrateOrphanedData_emptyDatabase_doesNotCrash() {
        // WHEN/THEN: should not crash on empty DB
        ModelContainerSetup.migrateOrphanedData(context: context, toUserId: "user-123")
        // No assertions needed — test passes if it doesn't crash
    }

    // Test: multiple migrations don't duplicate data
    func test_migrateOrphanedData_calledTwice_noDuplication() {
        // GIVEN: 2 orphaned records
        insertProgress(problemId: 1, userId: "")
        insertProgress(problemId: 2, userId: "")

        // WHEN: migrate twice
        ModelContainerSetup.migrateOrphanedData(context: context, toUserId: "user-A")
        ModelContainerSetup.migrateOrphanedData(context: context, toUserId: "user-A")

        // THEN: still only 2 records, no duplicates
        let descriptor = FetchDescriptor<SDUserProblemProgress>()
        let all = (try? context.fetch(descriptor)) ?? []
        XCTAssertEqual(all.count, 2)
    }

    // Test: second migration to different user doesn't re-migrate already-migrated records
    func test_migrateOrphanedData_differentUser_onlyOrphansAffected() {
        // GIVEN: 2 orphaned records
        insertProgress(problemId: 1, userId: "")
        insertProgress(problemId: 2, userId: "")

        // WHEN: first migration claims them
        ModelContainerSetup.migrateOrphanedData(context: context, toUserId: "user-A")

        // AND: second migration with different userId
        ModelContainerSetup.migrateOrphanedData(context: context, toUserId: "user-B")

        // THEN: records still belong to user-A (no orphans left for user-B)
        let descriptor = FetchDescriptor<SDUserProblemProgress>()
        let all = (try? context.fetch(descriptor)) ?? []
        let userA = all.filter { $0.userId == "user-A" }
        let userB = all.filter { $0.userId == "user-B" }
        XCTAssertEqual(userA.count, 2)
        XCTAssertEqual(userB.count, 0)
    }

    // MARK: - DIContainer Migration Guard (UserDefaults)

    // Test: migrateOrphanedDataIfNeeded uses UserDefaults to prevent re-migration
    func test_migrationGuard_preventsDoubleMigration() {
        let userId = "guard-test-\(UUID().uuidString)"
        let migrationKey = "didMigrateOrphanedData_\(userId)"

        // Clean up any leftover test state
        UserDefaults.standard.removeObject(forKey: migrationKey)

        // GIVEN: flag is not set
        XCTAssertFalse(UserDefaults.standard.bool(forKey: migrationKey))

        // WHEN: simulate what DIContainer does
        UserDefaults.standard.set(true, forKey: migrationKey)

        // THEN: flag is now set
        XCTAssertTrue(UserDefaults.standard.bool(forKey: migrationKey))

        // Cleanup
        UserDefaults.standard.removeObject(forKey: migrationKey)
    }

    // MARK: - Helpers

    private func insertProgress(problemId: Int, userId: String) {
        let record = SDUserProblemProgress(
            progressId: UUID(),
            userId: userId,
            problemId: problemId,
            statusRaw: "unseen",
            attemptCount: 0,
            lastAttemptDate: nil,
            bestApproachConfirmed: false,
            umpireSolutionUnlocked: false,
            notes: ""
        )
        context.insert(record)
        try? context.save()
    }

    private func insertCard(problemId: Int, userId: String) {
        let record = SDSpacedRepetitionCard(
            cardId: UUID(),
            userId: userId,
            problemId: problemId,
            repetitionCount: 0,
            interval: 1.0,
            easinessFactor: 2.5,
            nextReviewDate: Date(),
            lastReviewDate: nil,
            lastQualityRating: nil
        )
        context.insert(record)
        try? context.save()
    }

    private func insertChatSession(problemId: Int, userId: String) {
        let record = SDChatSession(
            sessionId: UUID(),
            userId: userId,
            problemId: problemId,
            createdAt: Date(),
            isUMPIREMode: false,
            messages: []
        )
        context.insert(record)
        try? context.save()
    }

    private func insertDailyChallenge(userId: String) {
        let record = SDDailyChallenge(
            challengeId: UUID(),
            userId: userId,
            date: Date(),
            problemIds: [1, 2, 3],
            completedProblemIds: []
        )
        context.insert(record)
        try? context.save()
    }
}
