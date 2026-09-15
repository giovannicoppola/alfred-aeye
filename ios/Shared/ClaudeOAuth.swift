import CryptoKit
import Foundation

/// Claude Code's public OAuth client.
///
/// Aeye needs the same `sk-ant-oat01-…` access token the Mac side reads out of
/// the `Claude Code-credentials` Keychain item — `api.anthropic.com/api/oauth/usage`
/// accepts nothing else. A claude.ai browser session is a different credential
/// entirely, which is why signing in through a web view could never work.
///
/// Constants below match the shipped CLI (`claude` 2.1.x).
public enum ClaudeOAuth {
    public static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    /// Subscription (claude.ai) authorize page. Console/API accounts would use
    /// `https://platform.claude.com/oauth/authorize` instead.
    static let authorizeURL = URL(string: "https://claude.com/cai/oauth/authorize")!
    static let tokenURL = URL(string: "https://platform.claude.com/v1/oauth/token")!

    /// The only redirect URI this client registers. It renders `code#state` on
    /// screen for the user to copy, which is why sign-in ends with a paste
    /// rather than an automatic hand-back to the app.
    static let redirectURI = "https://platform.claude.com/oauth/code/callback"

    static let scopes = "user:inference user:profile"

    /// Refresh this far ahead of the stated expiry.
    static let refreshLeeway: TimeInterval = 120

    // MARK: - Flow

    /// One authorization attempt: the PKCE secrets plus the URL to open.
    public struct Attempt: Sendable {
        public let verifier: String
        public let state: String
        public let url: URL
    }

    public struct Tokens: Sendable {
        public var accessToken: String
        public var refreshToken: String?
        public var expiresAt: Date?

        public init(accessToken: String, refreshToken: String? = nil, expiresAt: Date? = nil) {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.expiresAt = expiresAt
        }
    }

    public static func begin() -> Attempt {
        let verifier = randomURLSafeString()
        let state = randomURLSafeString()
        let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))

        var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "code", value: "true"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]
        return Attempt(verifier: verifier, state: state, url: components.url!)
    }

    /// Exchanges what the user pasted back from the callback page. The page
    /// shows `code#state`; a bare code (or a full callback URL) is accepted too.
    public static func exchange(pasted: String, attempt: Attempt) async throws -> Tokens {
        let (code, returnedState) = try parse(pasted: pasted)
        if let returnedState, returnedState != attempt.state {
            throw ClaudeOAuthError.stateMismatch
        }
        return try await post([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "code_verifier": attempt.verifier,
            "state": attempt.state,
        ])
    }

    public static func refresh(refreshToken: String) async throws -> Tokens {
        var tokens = try await post([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
        ])
        // Some responses omit a rotated refresh token; keep the one we have.
        if tokens.refreshToken == nil { tokens.refreshToken = refreshToken }
        return tokens
    }

    /// The stored access token, refreshed first if it is expired or about to be.
    ///
    /// Pasted tokens have no refresh token, so they are returned as-is until
    /// they 401 — same behaviour as before this flow existed.
    public static func validAccessToken(
        credentials: CredentialsStore = CredentialsStore(),
        forceRefresh: Bool = false
    ) async throws -> String {
        guard let stored = credentials.claudeOAuthToken, !stored.isEmpty else {
            throw ClaudeAPIError.missingToken
        }
        guard let refreshToken = credentials.claudeRefreshToken else { return stored }

        let expired = credentials.claudeTokenExpiry.map {
            Date().addingTimeInterval(refreshLeeway) >= $0
        } ?? false
        guard forceRefresh || expired else { return stored }

        let tokens = try await refresh(refreshToken: refreshToken)
        try credentials.saveClaudeTokens(tokens)
        return tokens.accessToken
    }

    // MARK: - Parsing

    static func parse(pasted: String) throws -> (code: String, state: String?) {
        var raw = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { throw ClaudeOAuthError.emptyCode }

        // Accept the whole callback URL as well as the displayed `code#state`.
        if raw.lowercased().hasPrefix("http"),
           let components = URLComponents(string: raw),
           let items = components.queryItems
        {
            guard let code = items.first(where: { $0.name == "code" })?.value else {
                throw ClaudeOAuthError.emptyCode
            }
            return (code, items.first(where: { $0.name == "state" })?.value)
        }

        if let hash = raw.firstIndex(of: "#") {
            let state = String(raw[raw.index(after: hash)...])
            raw = String(raw[..<hash])
            return (raw, state.isEmpty ? nil : state)
        }
        return (raw, nil)
    }

    // MARK: - Transport

    private static func post(_ body: [String: String]) async throws -> Tokens {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await AeyeHTTP.session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            // OAuth errors come back flat (`error_description`); Anthropic's own
            // gateway errors (rate limits, outages) come back nested under `error`.
            let nested = json["error"] as? [String: Any]
            let detail = json["error_description"] as? String
                ?? nested?["message"] as? String
                ?? json["error"] as? String
            throw ClaudeOAuthError.server(status: http.statusCode, detail: detail)
        }
        guard let access = json["access_token"] as? String, !access.isEmpty else {
            throw ClaudeAPIError.invalidResponse
        }
        let expiresAt = AeyeJSON.double(json["expires_in"]).map {
            Date().addingTimeInterval($0)
        }
        return Tokens(
            accessToken: access,
            refreshToken: json["refresh_token"] as? String,
            expiresAt: expiresAt
        )
    }

    // MARK: - PKCE helpers

    private static func randomURLSafeString() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max) }
        }
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

public enum ClaudeOAuthError: LocalizedError {
    case emptyCode
    case stateMismatch
    case server(status: Int, detail: String?)

    public var errorDescription: String? {
        switch self {
        case .emptyCode:
            return "No authorization code found in what was pasted."
        case .stateMismatch:
            return "That code came from a different sign-in attempt. Start again."
        case .server(let status, let detail):
            if let detail, !detail.isEmpty {
                return "Claude sign-in failed (\(status)): \(detail)"
            }
            return "Claude sign-in failed (HTTP \(status))."
        }
    }
}
