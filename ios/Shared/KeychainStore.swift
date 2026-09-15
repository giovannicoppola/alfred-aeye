import Foundation
import Security

public enum KeychainStore {
    public enum Key: String {
        case cursorSessionToken = "aeye.cursor.session"
        case claudeOAuthToken = "aeye.claude.oauth"
        case claudeRefreshToken = "aeye.claude.refresh"
        case claudeTokenExpiry = "aeye.claude.expiry"
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
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
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
        KeychainStore.load(for: .cursorSessionToken)
    }

    public var claudeOAuthToken: String? {
        KeychainStore.load(for: .claudeOAuthToken)
    }

    public func saveCursorSessionToken(_ token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainStore.delete(for: .cursorSessionToken)
        } else {
            try KeychainStore.save(trimmed, for: .cursorSessionToken)
        }
    }

    public var claudeRefreshToken: String? {
        guard let token = KeychainStore.load(for: .claudeRefreshToken),
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return token
    }

    public var claudeTokenExpiry: Date? {
        guard let raw = KeychainStore.load(for: .claudeTokenExpiry),
              let seconds = Double(raw)
        else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    /// Pasting a token clears any refresh token alongside it — the two are only
    /// ever valid as a pair.
    public func saveClaudeOAuthToken(_ token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainStore.delete(for: .claudeRefreshToken)
        KeychainStore.delete(for: .claudeTokenExpiry)
        if trimmed.isEmpty {
            KeychainStore.delete(for: .claudeOAuthToken)
        } else {
            try KeychainStore.save(trimmed, for: .claudeOAuthToken)
        }
    }

    public func saveClaudeTokens(_ tokens: ClaudeOAuth.Tokens) throws {
        try KeychainStore.save(
            tokens.accessToken.trimmingCharacters(in: .whitespacesAndNewlines),
            for: .claudeOAuthToken
        )
        if let refresh = tokens.refreshToken, !refresh.isEmpty {
            try KeychainStore.save(refresh, for: .claudeRefreshToken)
        } else {
            KeychainStore.delete(for: .claudeRefreshToken)
        }
        if let expiresAt = tokens.expiresAt {
            try KeychainStore.save(
                String(expiresAt.timeIntervalSince1970),
                for: .claudeTokenExpiry
            )
        } else {
            KeychainStore.delete(for: .claudeTokenExpiry)
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
