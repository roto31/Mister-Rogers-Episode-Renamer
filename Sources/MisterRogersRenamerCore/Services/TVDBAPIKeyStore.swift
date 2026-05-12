import Foundation
import Security

enum TVDBAPIKeyStore {
    private static let service = "com.misterrogers.renamer.tvdb"
    private static let account = "api_key"

    static func loadFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    static func saveToKeychain(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw KeychainError.emptyKey
        }
        guard let data = trimmed.data(using: .utf8) else {
            throw KeychainError.encodeFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var add: [String: Any] = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.osStatus(status)
        }
    }

    static func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Keychain first, then `TVDB_API_KEY` environment variable (for development).
    static func resolvedAPIKey() -> String? {
        if let k = loadFromKeychain(), !k.isEmpty { return k }
        let env = ProcessInfo.processInfo.environment["TVDB_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return env?.nilIfEmpty
    }

    enum KeychainError: Error, LocalizedError {
        case emptyKey
        case encodeFailed
        case osStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .emptyKey:
                return "API key is empty."
            case .encodeFailed:
                return "Could not encode API key."
            case let .osStatus(code):
                return "Keychain error (code \(code))."
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
