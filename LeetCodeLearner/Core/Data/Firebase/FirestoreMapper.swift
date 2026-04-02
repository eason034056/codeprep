import Foundation
import FirebaseFirestore

enum FirestoreMapper {

    // MARK: - Progress

    static func progressToFirestore(_ sd: SDUserProblemProgress) -> [String: Any] {
        var data: [String: Any] = [
            "progressId": sd.progressId.uuidString,
            "problemId": sd.problemId,
            "statusRaw": sd.statusRaw,
            "attemptCount": sd.attemptCount,
            "bestApproachConfirmed": sd.bestApproachConfirmed,
            "umpireSolutionUnlocked": sd.umpireSolutionUnlocked,
            "notes": sd.notes,
            "lastModified": sd.lastModified
        ]
        if let date = sd.lastAttemptDate {
            data["lastAttemptDate"] = date
        }
        return data
    }

    static func progressFromFirestore(_ data: [String: Any]) -> FirestoreProgress? {
        guard let progressId = data["progressId"] as? String,
              let problemId = data["problemId"] as? Int,
              let statusRaw = data["statusRaw"] as? String,
              let attemptCount = data["attemptCount"] as? Int,
              let bestApproachConfirmed = data["bestApproachConfirmed"] as? Bool,
              let umpireSolutionUnlocked = data["umpireSolutionUnlocked"] as? Bool,
              let notes = data["notes"] as? String,
              let lastModified = (data["lastModified"] as? Timestamp)?.dateValue() ?? data["lastModified"] as? Date
        else { return nil }

        return FirestoreProgress(
            progressId: progressId,
            problemId: problemId,
            statusRaw: statusRaw,
            attemptCount: attemptCount,
            lastAttemptDate: (data["lastAttemptDate"] as? Timestamp)?.dateValue() ?? data["lastAttemptDate"] as? Date,
            bestApproachConfirmed: bestApproachConfirmed,
            umpireSolutionUnlocked: umpireSolutionUnlocked,
            notes: notes,
            lastModified: lastModified
        )
    }

    // MARK: - Card

    static func cardToFirestore(_ sd: SDSpacedRepetitionCard) -> [String: Any] {
        var data: [String: Any] = [
            "cardId": sd.cardId.uuidString,
            "problemId": sd.problemId,
            "repetitionCount": sd.repetitionCount,
            "interval": sd.interval,
            "easinessFactor": sd.easinessFactor,
            "nextReviewDate": sd.nextReviewDate,
            "lastModified": sd.lastModified
        ]
        if let date = sd.lastReviewDate {
            data["lastReviewDate"] = date
        }
        if let rating = sd.lastQualityRating {
            data["lastQualityRating"] = rating
        }
        return data
    }

    static func cardFromFirestore(_ data: [String: Any]) -> FirestoreCard? {
        guard let cardId = data["cardId"] as? String,
              let problemId = data["problemId"] as? Int,
              let repetitionCount = data["repetitionCount"] as? Int,
              let interval = data["interval"] as? Double,
              let easinessFactor = data["easinessFactor"] as? Double,
              let nextReviewDate = (data["nextReviewDate"] as? Timestamp)?.dateValue() ?? data["nextReviewDate"] as? Date,
              let lastModified = (data["lastModified"] as? Timestamp)?.dateValue() ?? data["lastModified"] as? Date
        else { return nil }

        return FirestoreCard(
            cardId: cardId,
            problemId: problemId,
            repetitionCount: repetitionCount,
            interval: interval,
            easinessFactor: easinessFactor,
            nextReviewDate: nextReviewDate,
            lastReviewDate: (data["lastReviewDate"] as? Timestamp)?.dateValue() ?? data["lastReviewDate"] as? Date,
            lastQualityRating: data["lastQualityRating"] as? Int,
            lastModified: lastModified
        )
    }

    // MARK: - Daily Challenge

    static func challengeToFirestore(_ sd: SDDailyChallenge) -> [String: Any] {
        return [
            "challengeId": sd.challengeId.uuidString,
            "date": sd.date,
            "problemIds": sd.problemIds,
            "completedProblemIds": sd.completedProblemIds,
            "lastModified": sd.lastModified
        ]
    }

    static func challengeFromFirestore(_ data: [String: Any]) -> FirestoreDailyChallenge? {
        guard let challengeId = data["challengeId"] as? String,
              let date = (data["date"] as? Timestamp)?.dateValue() ?? data["date"] as? Date,
              let problemIds = data["problemIds"] as? [Int],
              let completedProblemIds = data["completedProblemIds"] as? [Int],
              let lastModified = (data["lastModified"] as? Timestamp)?.dateValue() ?? data["lastModified"] as? Date
        else { return nil }

        return FirestoreDailyChallenge(
            challengeId: challengeId,
            date: date,
            problemIds: problemIds,
            completedProblemIds: completedProblemIds,
            lastModified: lastModified
        )
    }

    // MARK: - Chat Session

    static func sessionToFirestore(_ sd: SDChatSession) -> [String: Any] {
        return [
            "sessionId": sd.sessionId.uuidString,
            "problemId": sd.problemId,
            "createdAt": sd.createdAt,
            "isUMPIREMode": sd.isUMPIREMode,
            "lastModified": sd.lastModified
        ]
    }

    static func sessionFromFirestore(_ data: [String: Any]) -> FirestoreChatSession? {
        guard let sessionId = data["sessionId"] as? String,
              let problemId = data["problemId"] as? Int,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? data["createdAt"] as? Date,
              let isUMPIREMode = data["isUMPIREMode"] as? Bool,
              let lastModified = (data["lastModified"] as? Timestamp)?.dateValue() ?? data["lastModified"] as? Date
        else { return nil }

        return FirestoreChatSession(
            sessionId: sessionId,
            problemId: problemId,
            createdAt: createdAt,
            isUMPIREMode: isUMPIREMode,
            lastModified: lastModified
        )
    }

    // MARK: - Chat Message

    static func messageToFirestore(_ sd: SDChatMessage) -> [String: Any] {
        var data: [String: Any] = [
            "messageId": sd.messageId.uuidString,
            "sessionId": sd.sessionId.uuidString,
            "roleRaw": sd.roleRaw,
            "content": sd.content,
            "timestamp": sd.timestamp,
            "lastModified": sd.lastModified
        ]
        if let step = sd.umpireStepRaw {
            data["umpireStepRaw"] = step
        }
        return data
    }

    static func messageFromFirestore(_ data: [String: Any]) -> FirestoreChatMessage? {
        guard let messageId = data["messageId"] as? String,
              let sessionId = data["sessionId"] as? String,
              let roleRaw = data["roleRaw"] as? String,
              let content = data["content"] as? String,
              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? data["timestamp"] as? Date,
              let lastModified = (data["lastModified"] as? Timestamp)?.dateValue() ?? data["lastModified"] as? Date
        else { return nil }

        return FirestoreChatMessage(
            messageId: messageId,
            sessionId: sessionId,
            roleRaw: roleRaw,
            content: content,
            timestamp: timestamp,
            umpireStepRaw: data["umpireStepRaw"] as? Int,
            lastModified: lastModified
        )
    }
}
