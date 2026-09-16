import Foundation

public struct OverviewRow: Codable, Sendable, Identifiable, Equatable {
    public var id: AeyeRowID
    public var label: String
    public var percentUsed: Double?
    public var titleLine: String
    public var subtitle: String
    public var copyText: String
    public var isError: Bool
    public var dashboardURL: URL?
    /// The trailing `(🕐 …)` detail, kept apart from ``titleLine`` so wider
    /// layouts can give it its own line. Optional so older cached snapshots
    /// still decode.
    public var suffix: String?

    public init(
        id: AeyeRowID,
        label: String,
        percentUsed: Double?,
        titleLine: String,
        subtitle: String,
        copyText: String,
        isError: Bool = false,
        dashboardURL: URL? = nil,
        suffix: String? = nil
    ) {
        self.id = id
        self.label = label
        self.percentUsed = percentUsed
        self.titleLine = titleLine
        self.subtitle = subtitle
        self.copyText = copyText
        self.isError = isError
        self.dashboardURL = dashboardURL
        self.suffix = suffix
    }
}

public struct AeyeSnapshot: Codable, Sendable, Equatable {
    public var capturedAt: Date
    public var rows: [OverviewRow]
    public var visibility: RowVisibility
    public var isMockData: Bool

    public init(
        capturedAt: Date = Date(),
        rows: [OverviewRow],
        visibility: RowVisibility = .allEnabled,
        isMockData: Bool = false
    ) {
        self.capturedAt = capturedAt
        self.rows = rows
        self.visibility = visibility
        self.isMockData = isMockData
    }

    public static let empty = AeyeSnapshot(
        capturedAt: .distantPast,
        rows: [],
        visibility: .allEnabled,
        isMockData: false
    )

    /// Error rows stay visible even if that source's toggle is off.
    public var visibleRows: [OverviewRow] {
        rows.filter { $0.isError || visibility.isEnabled($0.id) }
    }
}

public enum AeyeURLs {
    public static let cursorDashboard = URL(string: "https://cursor.com/dashboard")!
    public static let claudeUsage = URL(string: "https://claude.ai/settings/usage")!
}
