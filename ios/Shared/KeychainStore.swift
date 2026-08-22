import Foundation
import Security

public enum KeychainStore {
    public enum Key: String {
        case cursorSessionToken = "aeye.cursor.session"
        case claudeOAuthToken = "aeye.claude.oauth"
    }

    public static func save(_ value: String, for key: Key) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: "com.giovanni.aeye",
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    public static func load(for key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: "com.giovanni.aeye",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func delete(for key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: "com.giovanni.aeye",
        ]
        SecItemDelete(query as CFDictionary)
    }

    public enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Keychain save failed (status \(status))"
            }
        }
    }
}

public struct CredentialsStore {
    public var cursorSessionToken: String? {
        get { KeychainStore.load(for: .cursorSessionToken) }
        set {
            if let newValue, !newValue.isEmpty {
                try? KeychainStore.save(newValue, for: .cursorSessionToken)
            } else {
                KeychainStore.delete(for: .cursorSessionToken)
            }
        }
    }

    public var claudeOAuthToken: String? {
        get { KeychainStore.load(for: .claudeOAuthToken) }
        set {
            if let newValue, !newValue.isEmpty {
                try? KeychainStore.save(newValue, for: .claudeOAuthToken)
            } else {
                KeychainStore.delete(for: .claudeOAuthToken)
            }
        }
    }

    public var hasCursor: Bool {
        guard let token = cursorSessionToken else { return false }
        return !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var hasClaude: Bool {
        guard let token = claudeOAuthToken else { return false }
        return !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init() {}
}
