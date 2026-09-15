import CryptoKit
import Foundation

/// Cursor's browser login, the flow `cursor-agent` uses for `cursor login`.
///
/// The app opens `loginDeepControl` in a real browser and polls `/auth/poll`
/// until the user finishes; the poll returns the same session JWT the IDE keeps
/// in the `cursor-access-token` Keychain item, which is what the dashboard
/// cookie is built from. Nothing to paste, and SSO works because the sign-in
/// happens outside the app.
///
/// Constants match `cursor-agent` 2026.07.01.
public enum CursorAuth {
    static let websiteBase = "https://cursor.com"
    static let apiBase = "https://api2.cursor.sh"

    /// The CLI polls for ~25 minutes; a phone sheet does not need that long.
    static let maxAttempts = 90
    static let basePollInterval: TimeInterval = 1.0
    static let maxPollInterval: TimeInterval = 10.0
    static let maxConsecutiveFailures = 3

    public struct Attempt: Sendable {
        public let uuid: String
        public let verifier: String
        public let url: URL
    }

    public static func begin() -> Attempt {
        let verifier = base64URL(randomBytes(32))
        let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let uuid = UUID().uuidString

        var components = URLComponents(string: "\(websiteBase)/loginDeepControl")!
        components.queryItems = [
            URLQueryItem(name: "challenge", value: challenge),
            URLQueryItem(name: "uuid", value: uuid),
            URLQueryItem(name: "mode", value: "login"),
            URLQueryItem(name: "redirectTarget", value: "cli"),
        ]
        return Attempt(uuid: uuid, verifier: verifier, url: components.url!)
    }

    /// Waits for the browser half to finish and returns the session JWT.
    ///
    /// `404` means "not authorized yet" — that is the normal answer for most of
    /// this loop, not an error.
    public static func awaitToken(attempt: Attempt) async throws -> String {
        var components = URLComponents(string: "\(apiBase)/auth/poll")!
        components.queryItems = [
            URLQueryItem(name: "uuid", value: attempt.uuid),
            URLQueryItem(name: "verifier", value: attempt.verifier),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var consecutiveFailures = 0

        for attemptIndex in 0..<maxAttempts {
            try Task.checkCancellation()

            do {
                let (data, response) = try await AeyeHTTP.session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw CursorAuthError.invalidResponse
                }

                if http.statusCode == 404 {
                    consecutiveFailures = 0
                    try await backOff(attemptIndex)
                    continue
                }
                guard (200..<300).contains(http.statusCode) else {
                    consecutiveFailures += 1
                    if consecutiveFailures >= maxConsecutiveFailures {
                        throw CursorAuthError.server(status: http.statusCode)
                    }
                    try await backOff(attemptIndex)
                    continue
                }

                consecutiveFailures = 0
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let token = json["accessToken"] as? String,
                      !token.isEmpty
                else {
                    throw CursorAuthError.invalidResponse
                }
                return token
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as CursorAuthError {
                throw error
            } catch {
                consecutiveFailures += 1
                if consecutiveFailures >= maxConsecutiveFailures {
                    throw error
                }
                try await backOff(attemptIndex)
            }
        }

        throw CursorAuthError.timedOut
    }

    private static func backOff(_ attemptIndex: Int) async throws {
        let delay = min(basePollInterval * pow(1.2, Double(attemptIndex)), maxPollInterval)
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    private static func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        if SecRandomCopyBytes(kSecRandomDefault, count, &bytes) != errSecSuccess {
            bytes = (0..<count).map { _ in UInt8.random(in: .min ... .max) }
        }
        return Data(bytes)
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

public enum CursorAuthError: LocalizedError {
    case invalidResponse
    case server(status: Int)
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Cursor returned a sign-in response Aeye could not read."
        case .server(let status):
            return "Cursor sign-in failed (HTTP \(status))."
        case .timedOut:
            return "Timed out waiting for Cursor sign-in. Tap to try again."
        }
    }
}
