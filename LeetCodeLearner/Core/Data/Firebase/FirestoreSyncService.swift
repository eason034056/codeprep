import Foundation
import SwiftData
import FirebaseFirestore
import Combine

@MainActor
final class FirestoreSyncService: ObservableObject {
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncDate: Date?

    private let modelContainer: ModelContainer
    private var firestoreListeners: [ListenerRegistration] = []
    private var uploadTask: Task<Void, Never>?
    private var notificationObserver: Any?
    private var currentUserId: String?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Lifecycle

    func start(userId: String) {
        stop()
        currentUserId = userId

        notificationObserver = NotificationCenter.default.addObserver(
            forName: .localDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleUpload()
            }
        }

        Task {
            await performInitialMergeIfNeeded(userId: userId)
            attachListeners(userId: userId)
            await uploadPendingChanges(userId: userId)
        }
    }

    func stop() {
        detachListeners()
        uploadTask?.cancel()
        uploadTask = nil
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
        currentUserId = nil
    }

    // MARK: - Initial Merge

    private func performInitialMergeIfNeeded(userId: String) async {
        let key = "didInitialSync_\(userId)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        isSyncing = true
        let context = modelContainer.mainContext

        await uploadPendingChanges(userId: userId)
        await downloadRemoteData(userId: userId, context: context)

        UserDefaults.standard.set(true, forKey: key)
        isSyncing = false
    }

    // MARK: - Upload

    func scheduleUpload() {
        uploadTask?.cancel()
        uploadTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            guard let self, let userId = self.currentUserId else { return }
            await self.uploadPendingChanges(userId: userId)
        }
    }

    private func uploadPendingChanges(userId: String) async {
        let context = modelContainer.mainContext
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        let pendingUpload = "pendingUpload"

        // Upload progress
        let progressDescriptor = FetchDescriptor<SDUserProblemProgress>(
            predicate: #Predicate { $0.syncStatus == pendingUpload }
        )
        if let pending = try? context.fetch(progressDescriptor) {
            for record in pending where record.userId == userId {
                let docRef = userRef.collection("progress").document(record.progressId.uuidString)
                do {
                    try await docRef.setData(FirestoreMapper.progressToFirestore(record), merge: true)
                    record.syncStatus = "synced"
                } catch {
                    print("[Sync] Failed to upload progress: \(error)")
                }
            }
        }

        // Upload cards
        let cardDescriptor = FetchDescriptor<SDSpacedRepetitionCard>(
            predicate: #Predicate { $0.syncStatus == pendingUpload }
        )
        if let pending = try? context.fetch(cardDescriptor) {
            for record in pending where record.userId == userId {
                let docRef = userRef.collection("cards").document(record.cardId.uuidString)
                do {
                    try await docRef.setData(FirestoreMapper.cardToFirestore(record), merge: true)
                    record.syncStatus = "synced"
                } catch {
                    print("[Sync] Failed to upload card: \(error)")
                }
            }
        }

        // Upload daily challenges
        let challengeDescriptor = FetchDescriptor<SDDailyChallenge>(
            predicate: #Predicate { $0.syncStatus == pendingUpload }
        )
        if let pending = try? context.fetch(challengeDescriptor) {
            for record in pending where record.userId == userId {
                let docRef = userRef.collection("dailyChallenges").document(record.challengeId.uuidString)
                do {
                    try await docRef.setData(FirestoreMapper.challengeToFirestore(record), merge: true)
                    record.syncStatus = "synced"
                } catch {
                    print("[Sync] Failed to upload challenge: \(error)")
                }
            }
        }

        // Upload chat sessions
        let sessionDescriptor = FetchDescriptor<SDChatSession>(
            predicate: #Predicate { $0.syncStatus == pendingUpload }
        )
        if let pending = try? context.fetch(sessionDescriptor) {
            for record in pending where record.userId == userId {
                let docRef = userRef.collection("chatSessions").document(record.sessionId.uuidString)
                do {
                    try await docRef.setData(FirestoreMapper.sessionToFirestore(record), merge: true)
                    record.syncStatus = "synced"
                } catch {
                    print("[Sync] Failed to upload session: \(error)")
                }
            }
        }

        // Upload chat messages
        let messageDescriptor = FetchDescriptor<SDChatMessage>(
            predicate: #Predicate { $0.syncStatus == pendingUpload }
        )
        if let pending = try? context.fetch(messageDescriptor) {
            for record in pending {
                let docRef = userRef.collection("chatMessages").document(record.messageId.uuidString)
                do {
                    try await docRef.setData(FirestoreMapper.messageToFirestore(record), merge: true)
                    record.syncStatus = "synced"
                } catch {
                    print("[Sync] Failed to upload message: \(error)")
                }
            }
        }

        try? context.save()
        lastSyncDate = Date()
    }

    // MARK: - Download

    private func downloadRemoteData(userId: String, context: ModelContext) async {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)

        // Download progress
        if let snapshot = try? await userRef.collection("progress").getDocuments() {
            for document in snapshot.documents {
                guard let remote = FirestoreMapper.progressFromFirestore(document.data()),
                      let remoteUUID = UUID(uuidString: remote.progressId) else { continue }
                let existing = fetchProgress(id: remoteUUID, context: context)
                if let local = existing {
                    if shouldAcceptRemote(
                        localLastModified: local.lastModified,
                        remoteLastModified: remote.lastModified,
                        localSyncStatus: local.syncStatus
                    ) {
                        applyRemoteProgress(remote, to: local)
                    }
                } else {
                    insertProgressFromRemote(remote, userId: userId, context: context)
                }
            }
        }

        // Download cards
        if let snapshot = try? await userRef.collection("cards").getDocuments() {
            for document in snapshot.documents {
                guard let remote = FirestoreMapper.cardFromFirestore(document.data()),
                      let remoteUUID = UUID(uuidString: remote.cardId) else { continue }
                let existing = fetchCard(id: remoteUUID, context: context)
                if let local = existing {
                    if shouldAcceptRemote(
                        localLastModified: local.lastModified,
                        remoteLastModified: remote.lastModified,
                        localSyncStatus: local.syncStatus
                    ) {
                        applyRemoteCard(remote, to: local)
                    }
                } else {
                    insertCardFromRemote(remote, userId: userId, context: context)
                }
            }
        }

        // Download daily challenges
        if let snapshot = try? await userRef.collection("dailyChallenges").getDocuments() {
            for document in snapshot.documents {
                guard let remote = FirestoreMapper.challengeFromFirestore(document.data()),
                      let remoteUUID = UUID(uuidString: remote.challengeId) else { continue }
                let existing = fetchChallenge(id: remoteUUID, context: context)
                if let local = existing {
                    // Special merge: union completedProblemIds
                    mergeChallenge(remote: remote, local: local)
                } else {
                    insertChallengeFromRemote(remote, userId: userId, context: context)
                }
            }
        }

        // Download chat sessions
        if let snapshot = try? await userRef.collection("chatSessions").getDocuments() {
            for document in snapshot.documents {
                guard let remote = FirestoreMapper.sessionFromFirestore(document.data()),
                      let remoteUUID = UUID(uuidString: remote.sessionId) else { continue }
                let existing = fetchSession(id: remoteUUID, context: context)
                if let local = existing {
                    if shouldAcceptRemote(
                        localLastModified: local.lastModified,
                        remoteLastModified: remote.lastModified,
                        localSyncStatus: local.syncStatus
                    ) {
                        applyRemoteSession(remote, to: local)
                    }
                } else {
                    insertSessionFromRemote(remote, userId: userId, context: context)
                }
            }
        }

        // Download chat messages (append-only)
        if let snapshot = try? await userRef.collection("chatMessages").getDocuments() {
            for document in snapshot.documents {
                guard let remote = FirestoreMapper.messageFromFirestore(document.data()),
                      let remoteUUID = UUID(uuidString: remote.messageId) else { continue }
                let existing = fetchMessage(id: remoteUUID, context: context)
                if existing == nil {
                    insertMessageFromRemote(remote, context: context)
                }
            }
        }

        try? context.save()
    }

    // MARK: - Listeners

    private func attachListeners(userId: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        let context = modelContainer.mainContext

        // Progress listener
        let progressListener = userRef.collection("progress")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else { return }
                Task { @MainActor in
                    self.handleProgressChanges(snapshot.documentChanges, userId: userId, context: context)
                }
            }
        firestoreListeners.append(progressListener)

        // Cards listener
        let cardsListener = userRef.collection("cards")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else { return }
                Task { @MainActor in
                    self.handleCardChanges(snapshot.documentChanges, userId: userId, context: context)
                }
            }
        firestoreListeners.append(cardsListener)

        // Daily challenges listener
        let challengesListener = userRef.collection("dailyChallenges")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else { return }
                Task { @MainActor in
                    self.handleChallengeChanges(snapshot.documentChanges, userId: userId, context: context)
                }
            }
        firestoreListeners.append(challengesListener)

        // Chat sessions listener
        let sessionsListener = userRef.collection("chatSessions")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else { return }
                Task { @MainActor in
                    self.handleSessionChanges(snapshot.documentChanges, userId: userId, context: context)
                }
            }
        firestoreListeners.append(sessionsListener)

        // Chat messages listener
        let messagesListener = userRef.collection("chatMessages")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else { return }
                Task { @MainActor in
                    self.handleMessageChanges(snapshot.documentChanges, context: context)
                }
            }
        firestoreListeners.append(messagesListener)
    }

    private func detachListeners() {
        for listener in firestoreListeners {
            listener.remove()
        }
        firestoreListeners.removeAll()
    }

    // MARK: - Handle Listener Changes

    private func handleProgressChanges(_ changes: [DocumentChange], userId: String, context: ModelContext) {
        for change in changes {
            let data = change.document.data()
            guard let remote = FirestoreMapper.progressFromFirestore(data),
                  let remoteUUID = UUID(uuidString: remote.progressId) else { continue }

            switch change.type {
            case .added, .modified:
                let existing = fetchProgress(id: remoteUUID, context: context)
                if let local = existing {
                    if shouldAcceptRemote(
                        localLastModified: local.lastModified,
                        remoteLastModified: remote.lastModified,
                        localSyncStatus: local.syncStatus
                    ) {
                        applyRemoteProgress(remote, to: local)
                    }
                } else {
                    insertProgressFromRemote(remote, userId: userId, context: context)
                }

            case .removed:
                if let local = fetchProgress(id: remoteUUID, context: context) {
                    context.delete(local)
                }
            }
        }
        try? context.save()
    }

    private func handleCardChanges(_ changes: [DocumentChange], userId: String, context: ModelContext) {
        for change in changes {
            let data = change.document.data()
            guard let remote = FirestoreMapper.cardFromFirestore(data),
                  let remoteUUID = UUID(uuidString: remote.cardId) else { continue }

            switch change.type {
            case .added, .modified:
                let existing = fetchCard(id: remoteUUID, context: context)
                if let local = existing {
                    if shouldAcceptRemote(
                        localLastModified: local.lastModified,
                        remoteLastModified: remote.lastModified,
                        localSyncStatus: local.syncStatus
                    ) {
                        applyRemoteCard(remote, to: local)
                    }
                } else {
                    insertCardFromRemote(remote, userId: userId, context: context)
                }

            case .removed:
                if let local = fetchCard(id: remoteUUID, context: context) {
                    context.delete(local)
                }
            }
        }
        try? context.save()
    }

    private func handleChallengeChanges(_ changes: [DocumentChange], userId: String, context: ModelContext) {
        for change in changes {
            let data = change.document.data()
            guard let remote = FirestoreMapper.challengeFromFirestore(data),
                  let remoteUUID = UUID(uuidString: remote.challengeId) else { continue }

            switch change.type {
            case .added, .modified:
                let existing = fetchChallenge(id: remoteUUID, context: context)
                if let local = existing {
                    mergeChallenge(remote: remote, local: local)
                } else {
                    insertChallengeFromRemote(remote, userId: userId, context: context)
                }

            case .removed:
                if let local = fetchChallenge(id: remoteUUID, context: context) {
                    context.delete(local)
                }
            }
        }
        try? context.save()
    }

    private func handleSessionChanges(_ changes: [DocumentChange], userId: String, context: ModelContext) {
        for change in changes {
            let data = change.document.data()
            guard let remote = FirestoreMapper.sessionFromFirestore(data),
                  let remoteUUID = UUID(uuidString: remote.sessionId) else { continue }

            switch change.type {
            case .added, .modified:
                let existing = fetchSession(id: remoteUUID, context: context)
                if let local = existing {
                    if shouldAcceptRemote(
                        localLastModified: local.lastModified,
                        remoteLastModified: remote.lastModified,
                        localSyncStatus: local.syncStatus
                    ) {
                        applyRemoteSession(remote, to: local)
                    }
                } else {
                    insertSessionFromRemote(remote, userId: userId, context: context)
                }

            case .removed:
                if let local = fetchSession(id: remoteUUID, context: context) {
                    context.delete(local)
                }
            }
        }
        try? context.save()
    }

    private func handleMessageChanges(_ changes: [DocumentChange], context: ModelContext) {
        for change in changes {
            let data = change.document.data()
            guard let remote = FirestoreMapper.messageFromFirestore(data),
                  let remoteUUID = UUID(uuidString: remote.messageId) else { continue }

            switch change.type {
            case .added:
                // Append-only: insert if not exists
                if fetchMessage(id: remoteUUID, context: context) == nil {
                    insertMessageFromRemote(remote, context: context)
                }

            case .modified:
                // Messages are append-only; ignore modifications
                break

            case .removed:
                if let local = fetchMessage(id: remoteUUID, context: context) {
                    context.delete(local)
                }
            }
        }
        try? context.save()
    }

    // MARK: - Conflict Resolution

    private func shouldAcceptRemote(localLastModified: Date, remoteLastModified: Date, localSyncStatus: String) -> Bool {
        if localSyncStatus == "synced" { return true }
        return remoteLastModified > localLastModified
    }

    // MARK: - Apply Remote Data

    private func applyRemoteProgress(_ remote: FirestoreProgress, to local: SDUserProblemProgress) {
        local.statusRaw = remote.statusRaw
        local.attemptCount = remote.attemptCount
        local.lastAttemptDate = remote.lastAttemptDate
        local.bestApproachConfirmed = remote.bestApproachConfirmed
        local.umpireSolutionUnlocked = remote.umpireSolutionUnlocked
        local.notes = remote.notes
        local.lastModified = remote.lastModified
        local.syncStatus = "synced"
    }

    private func applyRemoteCard(_ remote: FirestoreCard, to local: SDSpacedRepetitionCard) {
        local.repetitionCount = remote.repetitionCount
        local.interval = remote.interval
        local.easinessFactor = remote.easinessFactor
        local.nextReviewDate = remote.nextReviewDate
        local.lastReviewDate = remote.lastReviewDate
        local.lastQualityRating = remote.lastQualityRating
        local.lastModified = remote.lastModified
        local.syncStatus = "synced"
    }

    private func mergeChallenge(remote: FirestoreDailyChallenge, local: SDDailyChallenge) {
        // Union-merge completedProblemIds
        let merged = Array(Set(local.completedProblemIds).union(Set(remote.completedProblemIds)))
        local.completedProblemIds = merged
        local.problemIds = remote.problemIds
        // Use whichever lastModified is newer
        if remote.lastModified > local.lastModified {
            local.lastModified = remote.lastModified
        }
        local.syncStatus = "synced"
    }

    private func applyRemoteSession(_ remote: FirestoreChatSession, to local: SDChatSession) {
        local.problemId = remote.problemId
        local.isUMPIREMode = remote.isUMPIREMode
        local.lastModified = remote.lastModified
        local.syncStatus = "synced"
    }

    // MARK: - Insert from Remote

    private func insertProgressFromRemote(_ remote: FirestoreProgress, userId: String, context: ModelContext) {
        guard let uuid = UUID(uuidString: remote.progressId) else { return }
        let record = SDUserProblemProgress(
            progressId: uuid,
            userId: userId,
            problemId: remote.problemId,
            statusRaw: remote.statusRaw,
            attemptCount: remote.attemptCount,
            lastAttemptDate: remote.lastAttemptDate,
            bestApproachConfirmed: remote.bestApproachConfirmed,
            umpireSolutionUnlocked: remote.umpireSolutionUnlocked,
            notes: remote.notes
        )
        record.lastModified = remote.lastModified
        record.syncStatus = "synced"
        context.insert(record)
    }

    private func insertCardFromRemote(_ remote: FirestoreCard, userId: String, context: ModelContext) {
        guard let uuid = UUID(uuidString: remote.cardId) else { return }
        let record = SDSpacedRepetitionCard(
            cardId: uuid,
            userId: userId,
            problemId: remote.problemId,
            repetitionCount: remote.repetitionCount,
            interval: remote.interval,
            easinessFactor: remote.easinessFactor,
            nextReviewDate: remote.nextReviewDate,
            lastReviewDate: remote.lastReviewDate,
            lastQualityRating: remote.lastQualityRating
        )
        record.lastModified = remote.lastModified
        record.syncStatus = "synced"
        context.insert(record)
    }

    private func insertChallengeFromRemote(_ remote: FirestoreDailyChallenge, userId: String, context: ModelContext) {
        guard let uuid = UUID(uuidString: remote.challengeId) else { return }
        let record = SDDailyChallenge(
            challengeId: uuid,
            userId: userId,
            date: remote.date,
            problemIds: remote.problemIds,
            completedProblemIds: remote.completedProblemIds
        )
        record.lastModified = remote.lastModified
        record.syncStatus = "synced"
        context.insert(record)
    }

    private func insertSessionFromRemote(_ remote: FirestoreChatSession, userId: String, context: ModelContext) {
        guard let uuid = UUID(uuidString: remote.sessionId) else { return }
        let record = SDChatSession(
            sessionId: uuid,
            userId: userId,
            problemId: remote.problemId,
            createdAt: remote.createdAt,
            isUMPIREMode: remote.isUMPIREMode
        )
        record.lastModified = remote.lastModified
        record.syncStatus = "synced"
        context.insert(record)
    }

    private func insertMessageFromRemote(_ remote: FirestoreChatMessage, context: ModelContext) {
        guard let messageUUID = UUID(uuidString: remote.messageId),
              let sessionUUID = UUID(uuidString: remote.sessionId) else { return }
        let record = SDChatMessage(
            messageId: messageUUID,
            sessionId: sessionUUID,
            roleRaw: remote.roleRaw,
            content: remote.content,
            timestamp: remote.timestamp,
            umpireStepRaw: remote.umpireStepRaw
        )
        record.lastModified = remote.lastModified
        record.syncStatus = "synced"

        // Link to parent session if it exists locally
        let existing = fetchSession(id: sessionUUID, context: context)
        if let session = existing {
            record.session = session
        }

        context.insert(record)
    }

    // MARK: - Fetch Helpers

    private func fetchProgress(id: UUID, context: ModelContext) -> SDUserProblemProgress? {
        let descriptor = FetchDescriptor<SDUserProblemProgress>(
            predicate: #Predicate { $0.progressId == id }
        )
        return try? context.fetch(descriptor).first
    }

    private func fetchCard(id: UUID, context: ModelContext) -> SDSpacedRepetitionCard? {
        let descriptor = FetchDescriptor<SDSpacedRepetitionCard>(
            predicate: #Predicate { $0.cardId == id }
        )
        return try? context.fetch(descriptor).first
    }

    private func fetchChallenge(id: UUID, context: ModelContext) -> SDDailyChallenge? {
        let descriptor = FetchDescriptor<SDDailyChallenge>(
            predicate: #Predicate { $0.challengeId == id }
        )
        return try? context.fetch(descriptor).first
    }

    private func fetchSession(id: UUID, context: ModelContext) -> SDChatSession? {
        let descriptor = FetchDescriptor<SDChatSession>(
            predicate: #Predicate { $0.sessionId == id }
        )
        return try? context.fetch(descriptor).first
    }

    private func fetchMessage(id: UUID, context: ModelContext) -> SDChatMessage? {
        let descriptor = FetchDescriptor<SDChatMessage>(
            predicate: #Predicate { $0.messageId == id }
        )
        return try? context.fetch(descriptor).first
    }
}
