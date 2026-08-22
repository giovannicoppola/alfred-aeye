import Foundation

public enum ClaudeAPIError: LocalizedError {
    case missingToken
    case http(status: Int)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Claude OAuth token not configured. Paste your Claude Code OAuth token in Settings."
        case .http(let status):
            return "Claude HTTP \(status)"
        case .invalidResponse:
            return "Invalid Claude response"
        }
    }
}

public struct ClaudeLimitWindow: Sendable {
    public var usedPercentage: Double?
    public var resetsAt: Date?
}

public struct ClaudeUsageData: Sendable {
    public var plan: String
    public var confidence: String
    public var fiveHour: ClaudeLimitWindow
    public var sevenDay: ClaudeLimitWindow
    public var sessionActive: Bool
    public var sessionCostUSD: Double?
    public var statusLabel: String?
}

public struct ClaudeClient: Sendable {
    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let oauthToken: String
    private let session: URLSession

    public init(oauthToken: String, session: URLSession = .shared) {
        self.oauthToken = oauthToken.trimmingCharacters(in: .whitespacesAndNewlines)
        self.session = session
    }

    public func fetchUsage() async throws -> ClaudeUsageData {
        var request = URLRequest(url: Self.usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(oauthToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/aeye-ios", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClaudeAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw ClaudeAPIError.http(status: http.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeAPIError.invalidResponse
        }
        return parse(json)
    }

    private func parse(_ payload: [String: Any]) -> ClaudeUsageData {
        let now = Date()
        let fromLimits = parseLimitsArray(payload["limits"], now: now)
        let rateLimits = payload["rate_limits"] as? [String: Any] ?? payload

        let five = fromLimits?.five ?? parseWindow(rateLimits["five_hour"], now: now)
        let seven = fromLimits?.seven ?? parseWindow(rateLimits["seven_day"], now: now)

        return ClaudeUsageData(
            plan: payload["plan"] as? String ?? "unknown",
            confidence: "experimental",
            fiveHour: five,
            sevenDay: seven,
            sessionActive: false,
            sessionCostUSD: nil,
            statusLabel: nil
        )
    }

    private struct LimitsPair {
        var five: ClaudeLimitWindow
        var seven: ClaudeLimitWindow
    }

    private func parseLimitsArray(_ raw: Any?, now: Date) -> LimitsPair? {
        guard let items = raw as? [[String: Any]], !items.isEmpty else { return nil }
        var five: ClaudeLimitWindow?
        var seven: ClaudeLimitWindow?
        for item in items {
            guard let kind = item["kind"] as? String else { continue }
            let window = parseWindow(item, now: now)
            if kind == "session" { five = window }
            if kind == "weekly_all" || kind == "weekly" { seven = window }
        }
        guard five != nil || seven != nil else { return nil }
        return LimitsPair(
            five: five ?? ClaudeLimitWindow(),
            seven: seven ?? ClaudeLimitWindow()
        )
    }

    private func parseWindow(_ raw: Any?, now: Date) -> ClaudeLimitWindow {
        guard let dict = raw as? [String: Any] else {
            return ClaudeLimitWindow()
        }
        let utilization = dict["utilization"] ?? dict["used_percentage"] ?? dict["percent"]
        var pct = utilizationToPercent(utilization)
        let reset = AeyeFormatting.parseResetDate(
            raw: dict["resets_at"],
            epoch: dict["resets_at_epoch"] as? Int
        )
        if let reset, now >= reset { pct = nil }
        return ClaudeLimitWindow(usedPercentage: pct, resetsAt: reset)
    }

    private func utilizationToPercent(_ value: Any?) -> Double? {
        guard let value else { return nil }
        if let b = value as? Bool, b { return nil }
        var num: Double?
        if let d = value as? Double { num = d }
        if let i = value as? Int { num = Double(i) }
        guard let num, num.isFinite, num >= 0 else { return nil }
        if num > 100 { return num <= 101 ? 100.0 : nil }
        return (num * 10).rounded() / 10
    }
}
