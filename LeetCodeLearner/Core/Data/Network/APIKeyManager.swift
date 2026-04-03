import Foundation
import Security

final class APIKeyManager: Sendable {
    static let shared = APIKeyManager()
    private let service = "com.codereps.openrouter-api"
    private let account = "api-key"

    private init() {}

    func store(apiKey: String) throws {
        let data = Data(apiKey.utf8)

        // Delete existing key first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToStore
        }
    }

    func retrieve() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.notFound
        }
        return key
    }

    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete
        }
    }

    var hasKey: Bool {
        (try? retrieve()) != nil
    }
}

enum KeychainError: LocalizedError {
    case unableToStore
    case notFound
    case unableToDelete

    var errorDescription: String? {
        switch self {
        case .unableToStore: return "Unable to store API key in Keychain"
        case .notFound: return "API key not found in Keychain"
        case .unableToDelete: return "Unable to delete API key from Keychain"
        }
    }
}
