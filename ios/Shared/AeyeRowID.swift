import Foundation

/// Overview rows — same order and labels as the Alfred workflow.
public enum AeyeRowID: String, Codable, CaseIterable, Sendable, Identifiable {
    case composerAuto = "cursor_auto"
    case otherModels = "cursor_other"
    case grokBot = "cursor_grok"
    case hourly = "claude_hourly"
    case weekly = "claude_weekly"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .composerAuto: return "Composer / Auto"
        case .otherModels: return "Other models"
        case .grokBot: return "Grok Bot"
        case .hourly: return "Hourly"
        case .weekly: return "Weekly"
        }
    }

    /// Short label for Apple Watch faces and complications.
    public var shortLabel: String {
        switch self {
        case .composerAuto: return "Auto"
        case .otherModels: return "Other"
        case .grokBot: return "Grok"
        case .hourly: return "Hourly"
        case .weekly: return "Weekly"
        }
    }

    /// Which service the row comes from — shown next to the short label on the
    /// Watch, where "Auto" and "Hourly" alone do not say who they belong to.
    public var provider: String {
        isCursor ? "Cursor" : "Claude"
    }

    public var isCursor: Bool {
        switch self {
        case .composerAuto, .otherModels, .grokBot: return true
        case .hourly, .weekly: return false
        }
    }
}

public struct RowVisibility: Codable, Sendable, Equatable {
    public var cursorAuto: Bool
    public var cursorOther: Bool
    public var cursorGrokBot: Bool
    public var claudeHourly: Bool
    public var claudeWeekly: Bool

    public static let allEnabled = RowVisibility(
        cursorAuto: true,
        cursorOther: true,
        cursorGrokBot: true,
        claudeHourly: true,
        claudeWeekly: true
    )

    public init(
        cursorAuto: Bool,
        cursorOther: Bool,
        cursorGrokBot: Bool,
        claudeHourly: Bool,
        claudeWeekly: Bool
    ) {
        self.cursorAuto = cursorAuto
        self.cursorOther = cursorOther
        self.cursorGrokBot = cursorGrokBot
        self.claudeHourly = claudeHourly
        self.claudeWeekly = claudeWeekly
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cursorAuto = try container.decode(Bool.self, forKey: .cursorAuto)
        cursorOther = try container.decode(Bool.self, forKey: .cursorOther)
        cursorGrokBot = try container.decodeIfPresent(Bool.self, forKey: .cursorGrokBot) ?? true
        claudeHourly = try container.decode(Bool.self, forKey: .claudeHourly)
        claudeWeekly = try container.decode(Bool.self, forKey: .claudeWeekly)
    }

    public func isEnabled(_ row: AeyeRowID) -> Bool {
        switch row {
        case .composerAuto: return cursorAuto
        case .otherModels: return cursorOther
        case .grokBot: return cursorGrokBot
        case .hourly: return claudeHourly
        case .weekly: return claudeWeekly
        }
    }

    public var enabledRows: [AeyeRowID] {
        AeyeRowID.allCases.filter { isEnabled($0) }
    }
}
