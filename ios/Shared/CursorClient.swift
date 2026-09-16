import Foundation

public enum CursorAPIError: LocalizedError {
    case missingSession
    case http(status: Int, body: String)
    case invalidResponse
    case noLimitsData

    public var errorDescription: String? {
        switch self {
        case .missingSession:
            return "Cursor session token not configured. Paste your WorkosCursorSessionToken in Settings."
        case .http(let status, _):
            if status == 401 || status == 403 {
                return "Cursor HTTP \(status) — session expired. Paste a new token in Settings."
            }
            return "Cursor HTTP \(status)"
        case .invalidResponse:
            return "Invalid Cursor response"
        case .noLimitsData:
            return "Cycle limits unavailable"
        }
    }
}

public struct CursorUsageData: Sendable {
    public var email: String
    public var autoPercentUsed: Double?
    public var apiPercentUsed: Double?
    public var totalSpendCents: Double?
    public var limitCents: Double?
    public var autoMessage: String?
    public var apiMessage: String?
    public var billingStart: Date?
    public var billingEnd: Date?
}

public struct GrokBotUsage: Sendable {
    public var usagePercent: Double?
    public var periodStart: Date?
    public var periodEnd: Date?
    public var hasAvailableUsage: Bool?
    public var cursorPlanName: String?
    public var grokPlanLabel: String?
}

public struct CursorClient: Sendable {
    private static let base = URL(string: "https://cursor.com")!
    private let cookieValue: String
    private let session: URLSession

    public init(cookieValue: String, session: URLSession = AeyeHTTP.session) {
        self.cookieValue = cookieValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "%3A%3A", with: "::")
        self.session = session
    }

    public static func normalizeCookieValue(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "%3A%3A", with: "::")
        if trimmed.contains("::") { return trimmed }
        if let sub = jwtSub(from: trimmed) {
            return "\(sub)::\(trimmed)"
        }
        return trimmed
    }

    public func fetchUsage() async throws -> CursorUsageData {
        let me = try await request(path: "/api/auth/me")
        let email = me["email"] as? String ?? "signed-in user"

        var payload: [String: Any]?
        do {
            payload = try await request(path: "/api/dashboard/get-current-period-usage", method: "POST", body: [:])
        } catch {
            payload = try? await request(path: "/api/usage-summary")
        }
        guard let payload else { throw CursorAPIError.noLimitsData }

        let plan = (payload["planUsage"] as? [String: Any])
            ?? ((payload["individualUsage"] as? [String: Any])?["plan"] as? [String: Any])
            ?? [:]

        return CursorUsageData(
            email: email,
            autoPercentUsed: AeyeJSON.double(plan["autoPercentUsed"]),
            apiPercentUsed: AeyeJSON.double(plan["apiPercentUsed"]),
            totalSpendCents: AeyeJSON.double(plan["totalSpend"]) ?? AeyeJSON.double(plan["used"]),
            limitCents: AeyeJSON.double(plan["limit"]),
            autoMessage: payload["autoModelSelectedDisplayMessage"] as? String,
            apiMessage: payload["namedModelSelectedDisplayMessage"] as? String,
            billingStart: AeyeFormatting.parseResetDate(raw: payload["billingCycleStart"]),
            billingEnd: AeyeFormatting.parseResetDate(raw: payload["billingCycleEnd"])
        )
    }

    /// Weekly Grok Bot included usage. Returns `nil` when the account has no grant.
    public func fetchGrokBotUsage() async throws -> GrokBotUsage? {
        let payload = try await request(
            path: "/api/dashboard/get-sand-usage-status",
            method: "POST",
            body: [:]
        )
        guard AeyeJSON.bool(payload["hasNonZeroIncludedLimit"]) == true else {
            return nil
        }
        return GrokBotUsage(
            usagePercent: AeyeJSON.double(payload["usagePercent"]),
            periodStart: AeyeFormatting.parseResetDate(raw: payload["currentPeriodStart"]),
            periodEnd: AeyeFormatting.parseResetDate(raw: payload["nextResetTimestampUtc"]),
            hasAvailableUsage: AeyeJSON.bool(payload["hasAvailableUsage"]),
            cursorPlanName: payload["cursorPlanName"] as? String,
            grokPlanLabel: payload["grokPlanLabel"] as? String
        )
    }

    private func request(
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> [String: Any] {
        guard let url = URL(string: path, relativeTo: Self.base) else {
            throw CursorAPIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("cursor-usage/aeye-ios", forHTTPHeaderField: "User-Agent")
        request.setValue(
            "WorkosCursorSessionToken=\(cookieValue.replacingOccurrences(of: "::", with: "%3A%3A"))",
            forHTTPHeaderField: "Cookie"
        )
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("https://cursor.com", forHTTPHeaderField: "Origin")
            request.httpBody = try JSONSerialization.data(withJSONObject: body ?? [:])
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CursorAPIError.invalidResponse }
        let bodyText = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            throw CursorAPIError.http(status: http.statusCode, body: bodyText)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CursorAPIError.invalidResponse
        }
        return json
    }

    private static func jwtSub(from token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload.base64URLToBase64()),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String
        else { return nil }
        return sub.split(separator: "|").last.map(String.init)
    }
}

private extension String {
    func base64URLToBase64() -> String {
        var s = replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        s += String(repeating: "=", count: (4 - s.count % 4) % 4)
        return s
    }
}
