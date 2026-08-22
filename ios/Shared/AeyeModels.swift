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

    public init(
        id: AeyeRowID,
        label: String,
        percentUsed: Double?,
        titleLine: String,
        subtitle: String,
        copyText: String,
        isError: Bool = false,
        dashboardURL: URL? = nil
    ) {
        self.id = id
        self.label = label
        self.percentUsed = percentUsed
        self.titleLine = titleLine
        self.subtitle = subtitle
        self.copyText = copyText
        self.isError = isError
        self.dashboardURL = dashboardURL
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

    public var visibleRows: [OverviewRow] {
        rows.filter { visibility.isEnabled($0.id) }
    }
}

public enum AeyeURLs {
    public static let cursorDashboard = URL(string: "https://cursor.com/dashboard")!
    public static let claudeUsage = URL(string: "https://claude.ai/settings/usage")!
}
