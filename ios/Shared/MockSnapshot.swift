import Foundation

public enum MockSnapshot {
    public static let preview = AeyeSnapshot(
        capturedAt: Date(),
        rows: [
            OverviewRow(
                id: .composerAuto,
                label: "Composer / Auto",
                percentUsed: 13.0,
                titleLine: "Composer / Auto  🟢⚪⚪⚪⚪⚪⚪⚪⚪⚪  13.0%  (🕐 68%, 11d, Tue Aug 21) 🐢",
                subtitle: "… · $39.85 / $20.00",
                copyText: "Cursor Composer/Auto: 13.0%",
                dashboardURL: AeyeURLs.cursorDashboard
            ),
            OverviewRow(
                id: .otherModels,
                label: "Other models",
                percentUsed: 0.0,
                titleLine: "Other models  ⚪⚪⚪⚪⚪⚪⚪⚪⚪⚪  0.0%  (🕐 68%, 11d, Tue Aug 21) 🐢",
                subtitle: "…",
                copyText: "Cursor other models: 0.0%",
                dashboardURL: AeyeURLs.cursorDashboard
            ),
            OverviewRow(
                id: .hourly,
                label: "Hourly",
                percentUsed: 6.0,
                titleLine: "Hourly  🟢⚪⚪⚪⚪⚪⚪⚪⚪⚪  6.0%  (🕐 40%, 5h, 11:30pm) 🐢",
                subtitle: "plan=pro · experimental",
                copyText: "Claude hourly: 6.0%",
                dashboardURL: AeyeURLs.claudeUsage
            ),
            OverviewRow(
                id: .weekly,
                label: "Weekly",
                percentUsed: 1.0,
                titleLine: "Weekly  ⚪⚪⚪⚪⚪⚪⚪⚪⚪⚪  1.0%  (🕐 14%, 6d, Tue 8pm) 🎯",
                subtitle: "plan=pro · experimental",
                copyText: "Claude weekly: 1.0%",
                dashboardURL: AeyeURLs.claudeUsage
            ),
        ],
        visibility: .allEnabled,
        isMockData: true
    )
}
