import Foundation
import SwiftUI
import SwiftData

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var hasAPIKey: Bool = false
    @Published var notificationTime1 = DateComponents(hour: 9, minute: 0)
    @Published var notificationTime2 = DateComponents(hour: 13, minute: 0)
    @Published var notificationTime3 = DateComponents(hour: 19, minute: 0)
    @Published var selectedPath: LearningPath = .grind75
    @Published var selectedModel: String = "anthropic/claude-sonnet-4-20250514"
    @Published var isCustomModel: Bool = false
    @Published var customModelText: String = ""
    @Published var showSaveConfirmation: Bool = false
    @Published var showModelApplied: Bool = false
    @Published var errorMessage: String?
    @Published var showDeleteConfirmation: Bool = false
    @Published var showExportSheet: Bool = false
    @Published var authErrorMessage: String?
    var exportFileURL: URL?

    private let apiKeyManager: APIKeyManager
    private let authManager: AuthManager
    var modelContainer: ModelContainer?

    let availableModels = [
        "anthropic/claude-sonnet-4-20250514",
        "anthropic/claude-haiku-4-5-20251001",
        "openai/gpt-4o",
        "google/gemini-2.0-flash-001"
    ]

    var currentUserEmail: String? { authManager.currentUser?.email }
    var currentUserName: String? { authManager.currentUser?.displayName }
    var isAuthenticated: Bool { authManager.isAuthenticated }

    init(apiKeyManager: APIKeyManager = .shared, authManager: AuthManager) {
        self.apiKeyManager = apiKeyManager
        self.authManager = authManager
        self.hasAPIKey = apiKeyManager.hasKey

        // Load saved preferences
        if let path = UserDefaults.standard.string(forKey: "learningPath"),
           let lp = LearningPath(rawValue: path) {
            selectedPath = lp
        }
        if let model = UserDefaults.standard.string(forKey: "selectedModel") {
            selectedModel = model
            if !availableModels.contains(model) {
                isCustomModel = true
                customModelText = model
            }
        }
    }

    func saveAPIKey() {
        guard !apiKey.isEmpty else { return }
        do {
            try apiKeyManager.store(apiKey: apiKey)
            hasAPIKey = true
            apiKey = ""
            showSaveConfirmation = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAPIKey() {
        try? apiKeyManager.delete()
        hasAPIKey = false
    }

    func saveLearningPath() {
        UserDefaults.standard.set(selectedPath.rawValue, forKey: "learningPath")
    }

    func saveModel() {
        UserDefaults.standard.set(selectedModel, forKey: "selectedModel")
    }

    func applyCustomModel() {
        let trimmed = customModelText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selectedModel = trimmed
        saveModel()
        showModelApplied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showModelApplied = false
        }
    }

    func switchToPreset(_ model: String) {
        isCustomModel = false
        customModelText = ""
        selectedModel = model
        saveModel()
    }

    func switchToCustom() {
        isCustomModel = true
        customModelText = selectedModel
    }

    func dateFromComponents(_ components: DateComponents) -> Date {
        Calendar.current.date(from: components) ?? Date()
    }

    func componentsFromDate(_ date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: date)
    }

    // MARK: - Data Management

    func deleteAllData() {
        guard let container = modelContainer else { return }
        let context = container.mainContext

        do {
            try context.delete(model: SDUserProblemProgress.self)
            try context.delete(model: SDChatMessage.self)
            try context.delete(model: SDChatSession.self)
            try context.delete(model: SDSpacedRepetitionCard.self)
            try context.delete(model: SDDailyChallenge.self)
            try context.save()
        } catch {
            errorMessage = "Failed to delete data: \(error.localizedDescription)"
            return
        }

        // Clear Keychain
        try? apiKeyManager.delete()
        hasAPIKey = false

        // Clear UserDefaults
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "learningPath")
        defaults.removeObject(forKey: "selectedModel")
        defaults.removeObject(forKey: "hasCompletedOnboarding")

        // Reset local state
        selectedPath = .grind75
        selectedModel = availableModels[0]
        isCustomModel = false
        customModelText = ""

        HapticManager.shared.medium()
    }

    func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            authErrorMessage = "Unable to present sign-in"
            return
        }
        authErrorMessage = nil
        Task {
            do {
                try await authManager.signInWithGoogle(presenting: rootVC)
            } catch {
                authErrorMessage = error.localizedDescription
            }
        }
    }

    func signInWithApple() {
        authErrorMessage = nil
        Task {
            do {
                try await authManager.signInWithApple()
            } catch {
                authErrorMessage = error.localizedDescription
            }
        }
    }

    func signOut() {
        authManager.signOut()
    }

    func exportData() {
        guard let container = modelContainer else { return }
        let context = container.mainContext

        var exportDict: [String: Any] = [:]
        exportDict["exportDate"] = ISO8601DateFormatter().string(from: Date())
        exportDict["appVersion"] = "1.0.0"

        // Export progress
        let progressDescriptor = FetchDescriptor<SDUserProblemProgress>()
        if let progressItems = try? context.fetch(progressDescriptor) {
            exportDict["progress"] = progressItems.map { item in
                [
                    "problemId": item.problemId,
                    "status": item.statusRaw,
                    "lastAttemptDate": item.lastAttemptDate.map { ISO8601DateFormatter().string(from: $0) } ?? ""
                ] as [String: Any]
            }
        }

        // Export chat sessions
        let sessionDescriptor = FetchDescriptor<SDChatSession>()
        if let sessions = try? context.fetch(sessionDescriptor) {
            exportDict["chatSessions"] = sessions.map { session in
                [
                    "problemId": session.problemId,
                    "createdAt": ISO8601DateFormatter().string(from: session.createdAt),
                    "messages": session.messages.sorted(by: { $0.timestamp < $1.timestamp }).map { msg in
                        [
                            "role": msg.roleRaw,
                            "content": msg.content,
                            "timestamp": ISO8601DateFormatter().string(from: msg.timestamp)
                        ]
                    }
                ] as [String: Any]
            }
        }

        // Export spaced repetition cards
        let cardDescriptor = FetchDescriptor<SDSpacedRepetitionCard>()
        if let cards = try? context.fetch(cardDescriptor) {
            exportDict["spacedRepetitionCards"] = cards.map { card in
                [
                    "problemId": card.problemId,
                    "interval": card.interval,
                    "easinessFactor": card.easinessFactor,
                    "repetitionCount": card.repetitionCount,
                    "nextReviewDate": ISO8601DateFormatter().string(from: card.nextReviewDate)
                ] as [String: Any]
            }
        }

        // Write to temp file
        do {
            let data = try JSONSerialization.data(withJSONObject: exportDict, options: [.prettyPrinted, .sortedKeys])
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("CodeReps_Export.json")
            try data.write(to: tempURL)
            exportFileURL = tempURL
            showExportSheet = true
        } catch {
            errorMessage = "Failed to export data: \(error.localizedDescription)"
        }
    }
}
