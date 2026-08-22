import Foundation

/// The four overview rows — same order and labels as the Alfred workflow.
public enum AeyeRowID: String, Codable, CaseIterable, Sendable, Identifiable {
    case composerAuto = "cursor_auto"
    case otherModels = "cursor_other"
    case hourly = "claude_hourly"
    case weekly = "claude_weekly"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .composerAuto: return "Composer / Auto"
        case .otherModels: return "Other models"
        case .hourly: return "Hourly"
        case .weekly: return "Weekly"
        }
    }

    /// Short label for Apple Watch faces and complications.
    public var shortLabel: String {
        switch self {
        case .composerAuto: return "Auto"
        case .otherModels: return "Other"
        case .hourly: return "Hourly"
        case .weekly: return "Weekly"
        }
    }

    public var isCursor: Bool {
        switch self {
        case .composerAuto, .otherModels: return true
        case .hourly, .weekly: return false
        }
    }
}

public struct RowVisibility: Codable, Sendable, Equatable {
    public var cursorAuto: Bool
    public var cursorOther: Bool
    public var claudeHourly: Bool
    public var claudeWeekly: Bool

    public static let allEnabled = RowVisibility(
        cursorAuto: true, cursorOther: true, claudeHourly: true, claudeWeekly: true
    )

    public func isEnabled(_ row: AeyeRowID) -> Bool {
        switch row {
        case .composerAuto: return cursorAuto
        case .otherModels: return cursorOther
        case .hourly: return claudeHourly
        case .weekly: return claudeWeekly
        }
    }

    public var enabledRows: [AeyeRowID] {
        AeyeRowID.allCases.filter { isEnabled($0) }
    }
}
