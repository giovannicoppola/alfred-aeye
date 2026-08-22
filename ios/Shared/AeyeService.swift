import Foundation

/// Builds the four-row overview — logic ported from ``src/aieye.py``.
public actor AeyeService {
    private var cachedSnapshot: AeyeSnapshot?
    private var cacheTimestamp: Date?
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

        var rows: [OverviewRow] = []

        if visibility.cursorAuto || visibility.cursorOther {
            rows.append(contentsOf: await cursorRows(visibility: visibility))
        }
        if visibility.claudeHourly || visibility.claudeWeekly {
            rows.append(contentsOf: await claudeRows(visibility: visibility))
        }

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

    private func cursorRows(visibility: RowVisibility) async -> [OverviewRow] {
        guard credentials.hasCursor, let raw = credentials.cursorSessionToken else {
            return cursorError("Cursor session token not set")
        }

        do {
            let client = CursorClient(cookieValue: CursorClient.normalizeCookieValue(raw))
            let data = try await client.fetchUsage()
            return buildCursorRows(from: data, visibility: visibility)
        } catch let error as CursorAPIError {
            return cursorError(error.localizedDescription)
        } catch {
            return cursorError(error.localizedDescription)
        }
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
                dashboardURL: AeyeURLs.cursorDashboard
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
                dashboardURL: AeyeURLs.cursorDashboard
            ))
        }
        return rows
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

    // MARK: - Claude rows

    private func claudeRows(visibility: RowVisibility) async -> [OverviewRow] {
        guard credentials.hasClaude, let token = credentials.claudeOAuthToken else {
            return claudeError("Claude OAuth token not set")
        }

        do {
            let client = ClaudeClient(oauthToken: token)
            let data = try await client.fetchUsage()
            return buildClaudeRows(from: data, visibility: visibility)
        } catch let error as ClaudeAPIError {
            return claudeError(error.localizedDescription)
        } catch {
            return claudeError(error.localizedDescription)
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
                dashboardURL: AeyeURLs.claudeUsage
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
                dashboardURL: AeyeURLs.claudeUsage
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
