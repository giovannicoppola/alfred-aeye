import Foundation

/// Builds the overview — logic ported from ``src/aieye.py``.
public actor AeyeService {
    private var cachedSnapshot: AeyeSnapshot?
    private var cacheTimestamp: Date?
    private var isFetching = false
    private var inFlightWaiters: [CheckedContinuation<AeyeSnapshot, Never>] = []
    private let credentials: CredentialsStore

    public init(credentials: CredentialsStore = CredentialsStore()) {
        self.credentials = credentials
    }

    public func fetchOverview(
        visibility: RowVisibility = SnapshotStore.loadVisibility(),
        forceRefresh: Bool = false
    ) async -> AeyeSnapshot {
        if !forceRefresh,
           let cached = cachedSnapshot,
           let cacheTimestamp,
           cached.visibility == visibility,
           Date().timeIntervalSince(cacheTimestamp) < AeyeFormatting.overviewCacheTTL
        {
            return cached
        }

        if isFetching {
            let snapshot = await withCheckedContinuation { continuation in
                inFlightWaiters.append(continuation)
            }
            if !forceRefresh { return snapshot }
        }

        isFetching = true
        let snapshot = await buildSnapshot(visibility: visibility)
        let waiters = inFlightWaiters
        inFlightWaiters = []
        isFetching = false
        for waiter in waiters {
            waiter.resume(returning: snapshot)
        }
        return snapshot
    }

    private func buildSnapshot(visibility: RowVisibility) async -> AeyeSnapshot {
        async let cursor = cursorRowsIfNeeded(visibility: visibility)
        async let claude = claudeRowsIfNeeded(visibility: visibility)
        var rows = await cursor
        rows.append(contentsOf: await claude)

        if rows.isEmpty {
            rows = [
                OverviewRow(
                    id: .composerAuto,
                    label: "Aeye",
                    percentUsed: nil,
                    titleLine: "Aeye: no rows enabled",
                    subtitle: "Turn on at least one row in Settings",
                    copyText: "",
                    isError: true
                ),
            ]
        }

        let snapshot = AeyeSnapshot(
            capturedAt: Date(),
            rows: rows,
            visibility: visibility
        )
        cachedSnapshot = snapshot
        cacheTimestamp = Date()
        SnapshotStore.save(snapshot)
        SnapshotStore.saveVisibility(visibility)
        return snapshot
    }

    // MARK: - Cursor rows

    private func cursorRowsIfNeeded(visibility: RowVisibility) async -> [OverviewRow] {
        guard visibility.cursorAuto || visibility.cursorOther || visibility.cursorGrokBot else {
            return []
        }
        return await cursorRows(visibility: visibility)
    }

    private func claudeRowsIfNeeded(visibility: RowVisibility) async -> [OverviewRow] {
        guard visibility.claudeHourly || visibility.claudeWeekly else { return [] }
        return await claudeRows(visibility: visibility)
    }

    private func cursorRows(visibility: RowVisibility) async -> [OverviewRow] {
        guard credentials.hasCursor, let raw = credentials.cursorSessionToken else {
            return cursorError("Cursor session token not set")
        }

        let client = CursorClient(cookieValue: CursorClient.normalizeCookieValue(raw))
        var rows: [OverviewRow] = []

        if visibility.cursorAuto || visibility.cursorOther {
            do {
                let data = try await client.fetchUsage()
                rows.append(contentsOf: buildCursorRows(from: data, visibility: visibility))
            } catch {
                rows.append(contentsOf: cursorError(error.localizedDescription))
            }
        }

        if visibility.cursorGrokBot {
            do {
                if let grok = try await client.fetchGrokBotUsage() {
                    rows.append(buildGrokBotRow(from: grok))
                }
            } catch {
                rows.append(grokBotError(error.localizedDescription))
            }
        }
        return rows
    }

    private func buildCursorRows(from data: CursorUsageData, visibility: RowVisibility) -> [OverviewRow] {
        let autoSuffix = AeyeFormatting.periodSuffix(
            end: data.billingEnd,
            start: data.billingStart,
            spentPercent: data.autoPercentUsed,
            style: .calendar
        )
        let otherSuffix = AeyeFormatting.periodSuffix(
            end: data.billingEnd,
            start: data.billingStart,
            spentPercent: data.apiPercentUsed,
            style: .calendar
        )

        var spendBits: [String] = []
        if let used = data.totalSpendCents, let limit = data.limitCents {
            spendBits.append("\(AeyeFormatting.moneyCents(used)) / \(AeyeFormatting.moneyCents(limit))")
        }

        var autoSubParts: [String] = []
        if let msg = data.autoMessage { autoSubParts.append(msg) }
        autoSubParts.append(contentsOf: spendBits)
        let autoSub = autoSubParts.isEmpty ? data.email : autoSubParts.joined(separator: " · ")

        let otherSub = data.apiMessage ?? "API / named models · \(data.email)"

        var rows: [OverviewRow] = []
        if visibility.cursorAuto {
            rows.append(OverviewRow(
                id: .composerAuto,
                label: AeyeRowID.composerAuto.label,
                percentUsed: data.autoPercentUsed,
                titleLine: AeyeFormatting.titleLine(
                    label: AeyeRowID.composerAuto.label,
                    percent: data.autoPercentUsed,
                    suffix: autoSuffix
                ),
                subtitle: autoSub,
                copyText: "Cursor Composer/Auto: \(AeyeFormatting.percentString(data.autoPercentUsed))\(autoSuffix)",
                dashboardURL: AeyeURLs.cursorDashboard,
                suffix: autoSuffix
            ))
        }
        if visibility.cursorOther {
            rows.append(OverviewRow(
                id: .otherModels,
                label: AeyeRowID.otherModels.label,
                percentUsed: data.apiPercentUsed,
                titleLine: AeyeFormatting.titleLine(
                    label: AeyeRowID.otherModels.label,
                    percent: data.apiPercentUsed,
                    suffix: otherSuffix
                ),
                subtitle: otherSub,
                copyText: "Cursor other models: \(AeyeFormatting.percentString(data.apiPercentUsed))\(otherSuffix)",
                dashboardURL: AeyeURLs.cursorDashboard,
                suffix: otherSuffix
            ))
        }
        return rows
    }

    private func buildGrokBotRow(from data: GrokBotUsage) -> OverviewRow {
        let suffix = AeyeFormatting.periodSuffix(
            end: data.periodEnd,
            start: data.periodStart,
            spentPercent: data.usagePercent,
            style: .weekday
        )
        var bits: [String] = []
        if let plan = data.cursorPlanName, !plan.isEmpty { bits.append(plan) }
        if let label = data.grokPlanLabel, !label.isEmpty { bits.append(label) }
        bits.append("weekly included")
        if data.hasAvailableUsage == false { bits.append("exhausted") }

        return OverviewRow(
            id: .grokBot,
            label: AeyeRowID.grokBot.label,
            percentUsed: data.usagePercent,
            titleLine: AeyeFormatting.titleLine(
                label: AeyeRowID.grokBot.label,
                percent: data.usagePercent,
                suffix: suffix
            ),
            subtitle: bits.joined(separator: " · "),
            copyText: "Grok Bot: \(AeyeFormatting.percentString(data.usagePercent))\(suffix)",
            dashboardURL: AeyeURLs.cursorDashboard,
            suffix: suffix
        )
    }

    private func cursorError(_ message: String) -> [OverviewRow] {
        [OverviewRow(
            id: .composerAuto,
            label: "Cursor",
            percentUsed: nil,
            titleLine: "Cursor: unavailable",
            subtitle: String(message.prefix(200)),
            copyText: message,
            isError: true,
            dashboardURL: AeyeURLs.cursorDashboard
        )]
    }

    private func grokBotError(_ message: String) -> OverviewRow {
        OverviewRow(
            id: .grokBot,
            label: "Grok Bot",
            percentUsed: nil,
            titleLine: "Grok Bot: unavailable",
            subtitle: String(message.prefix(200)),
            copyText: message,
            isError: true,
            dashboardURL: AeyeURLs.cursorDashboard
        )
    }

    // MARK: - Claude rows

    private func claudeRows(visibility: RowVisibility) async -> [OverviewRow] {
        guard credentials.hasClaude else {
            return claudeError("Claude OAuth token not set")
        }

        do {
            let data = try await fetchClaudeUsage()
            return buildClaudeRows(from: data, visibility: visibility)
        } catch {
            return claudeError(error.localizedDescription)
        }
    }

    /// Access tokens last hours, so refresh before spending a request — and once
    /// more if the server rejects a token we thought was still good.
    private func fetchClaudeUsage() async throws -> ClaudeUsageData {
        let token = try await ClaudeOAuth.validAccessToken(credentials: credentials)
        do {
            return try await ClaudeClient(oauthToken: token).fetchUsage()
        } catch ClaudeAPIError.http(let status) where status == 401 || status == 403 {
            guard credentials.claudeRefreshToken != nil else {
                throw ClaudeAPIError.http(status: status)
            }
            let refreshed = try await ClaudeOAuth.validAccessToken(
                credentials: credentials,
                forceRefresh: true
            )
            return try await ClaudeClient(oauthToken: refreshed).fetchUsage()
        }
    }

    private func buildClaudeRows(from data: ClaudeUsageData, visibility: RowVisibility) -> [OverviewRow] {
        let fiveEnd = data.fiveHour.resetsAt
        let sevenEnd = data.sevenDay.resetsAt
        let fiveStart = fiveEnd.map { $0.addingTimeInterval(-5 * 3600) }
        let sevenStart = sevenEnd.map { $0.addingTimeInterval(-7 * 86400) }

        let fiveSuffix: String
        if data.sessionActive {
            fiveSuffix = AeyeFormatting.periodSuffix(
                end: fiveEnd,
                start: fiveStart,
                spentPercent: data.fiveHour.usedPercentage,
                style: .clock
            )
        } else {
            fiveSuffix = ""
        }

        let sevenSuffix = AeyeFormatting.periodSuffix(
            end: sevenEnd,
            start: sevenStart,
            spentPercent: data.sevenDay.usedPercentage,
            style: .weekday
        )

        var hourlyBits = ["plan=\(data.plan)"]
        if data.confidence != "unknown" { hourlyBits.append(data.confidence) }
        if !data.sessionActive {
            if let reset = formatResetTime(fiveEnd) { hourlyBits.append(reset) }
            if let countdown = AeyeFormatting.resetCountdown(until: fiveEnd) {
                hourlyBits.append("(\(countdown))")
            }
        }
        if let label = data.statusLabel, label != "ok" { hourlyBits.append(label) }
        if let cost = data.sessionCostUSD {
            hourlyBits.append(String(format: "session $%.2f", cost))
        }

        var weeklyBits = ["plan=\(data.plan)"]
        if data.confidence != "unknown" { weeklyBits.append(data.confidence) }
        if sevenSuffix.isEmpty, let reset = formatResetDateTime(sevenEnd) {
            weeklyBits.append(reset)
        }

        var rows: [OverviewRow] = []
        if visibility.claudeHourly {
            rows.append(OverviewRow(
                id: .hourly,
                label: AeyeRowID.hourly.label,
                percentUsed: data.fiveHour.usedPercentage,
                titleLine: AeyeFormatting.titleLine(
                    label: AeyeRowID.hourly.label,
                    percent: data.fiveHour.usedPercentage,
                    suffix: fiveSuffix
                ),
                subtitle: hourlyBits.joined(separator: " · "),
                copyText: "Claude hourly: \(AeyeFormatting.percentString(data.fiveHour.usedPercentage))\(fiveSuffix)",
                dashboardURL: AeyeURLs.claudeUsage,
                suffix: fiveSuffix
            ))
        }
        if visibility.claudeWeekly {
            rows.append(OverviewRow(
                id: .weekly,
                label: AeyeRowID.weekly.label,
                percentUsed: data.sevenDay.usedPercentage,
                titleLine: AeyeFormatting.titleLine(
                    label: AeyeRowID.weekly.label,
                    percent: data.sevenDay.usedPercentage,
                    suffix: sevenSuffix
                ),
                subtitle: weeklyBits.joined(separator: " · "),
                copyText: "Claude weekly: \(AeyeFormatting.percentString(data.sevenDay.usedPercentage))\(sevenSuffix)",
                dashboardURL: AeyeURLs.claudeUsage,
                suffix: sevenSuffix
            ))
        }
        return rows
    }

    private func claudeError(_ message: String) -> [OverviewRow] {
        [OverviewRow(
            id: .hourly,
            label: "Claude",
            percentUsed: nil,
            titleLine: "Claude: unavailable",
            subtitle: String(message.prefix(200)),
            copyText: message,
            isError: true,
            dashboardURL: AeyeURLs.claudeUsage
        )]
    }

    private func formatResetTime(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatResetDateTime(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
