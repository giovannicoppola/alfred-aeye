import Foundation

/// Presentation helpers ported from ``src/aieye.py`` (circle meters, pace, suffixes).
public enum AeyeFormatting {
    public static let overviewCacheTTL: TimeInterval = 60
    public static let paceBand: Double = 8.0
    private static let meterWidth = 10

    // MARK: - Circle meter

    public static func bar(percent: Double?, width: Int = 10) -> String {
        let palette = (0..<width).map { slotColor(for: $0, width: width) }
        let empty = "⚪"
        guard let percent else { return String(repeating: empty, count: width) }
        let clamped = max(0, min(100, percent))
        var filled = Int(round(clamped / 100.0 * Double(width)))
        filled = max(0, min(width, filled))
        return (0..<width)
            .map { i in i < filled ? palette[i] : empty }
            .joined()
    }

    private static func slotColor(for index: Int, width: Int) -> String {
        let edge = Double(index + 1) / Double(width) * 100.0
        if edge <= 50 { return "🟢" }
        if edge <= 80 { return "🟡" }
        return "🔴"
    }

    // MARK: - Percent & money

    public static func percentString(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1f%%", value)
    }

    public static func moneyCents(_ cents: Double?) -> String {
        guard let cents else { return "n/a" }
        let dollars = cents / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: dollars)) ?? String(format: "$%.2f", dollars)
    }

    // MARK: - Reset countdown & detail

    public static func resetCountdown(until end: Date?) -> String? {
        guard let end else { return nil }
        let seconds = end.timeIntervalSinceNow
        if seconds <= 0 { return "now" }
        if seconds < 3600 {
            return "\(max(1, Int(round(seconds / 60.0))))m"
        }
        let hours = seconds / 3600.0
        if hours < 24 {
            return "\(max(1, Int(round(hours))))h"
        }
        return "\(max(1, Int(round(seconds / 86400.0))))d"
    }

    public enum ResetDetailStyle {
        case calendar
        case weekday
        case clock
    }

    public static func resetDetail(for end: Date?, style: ResetDetailStyle) -> String? {
        guard let end else { return nil }
        let local = end
        let calendar = Calendar.current
        switch style {
        case .calendar:
            let weekday = local.formatted(.dateTime.weekday(.abbreviated))
            let month = local.formatted(.dateTime.month(.abbreviated))
            let day = calendar.component(.day, from: local)
            return "\(weekday) \(month) \(day)"
        case .weekday:
            let weekday = local.formatted(.dateTime.weekday(.abbreviated))
            let hour = calendar.component(.hour, from: local)
            let minute = calendar.component(.minute, from: local)
            let (h12, ampm) = twelveHour(hour: hour, minute: minute)
            return "\(weekday) \(h12)\(ampm)"
        case .clock:
            let hour = calendar.component(.hour, from: local)
            let minute = calendar.component(.minute, from: local)
            let (h12, ampm) = twelveHour(hour: hour, minute: minute)
            let minStr = String(format: "%02d", minute)
            return "\(h12):\(minStr)\(ampm)"
        }
    }

    private static func twelveHour(hour: Int, minute: Int) -> (String, String) {
        var h = hour % 12
        if h == 0 { h = 12 }
        let ampm = hour < 12 ? "am" : "pm"
        return ("\(h)", ampm)
    }

    // MARK: - Period elapsed & pace

    public static func periodElapsedPercent(start: Date?, end: Date?) -> Double? {
        guard let start, let end else { return nil }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return nil }
        let done = Date().timeIntervalSince(start)
        let pct = done / total * 100.0
        return round(max(0, min(100, pct)))
    }

    public static func paceEmoji(spent: Double?, elapsed: Double?, band: Double = paceBand) -> String {
        guard let spent, let elapsed else { return "" }
        let diff = spent - elapsed
        if diff < -band { return "🐢" }
        if diff > band { return "🔥" }
        return "🎯"
    }

    public static func periodSuffix(
        end: Date?,
        start: Date? = nil,
        spentPercent: Double? = nil,
        style: ResetDetailStyle = .calendar
    ) -> String {
        guard let countdown = resetCountdown(until: end) else { return "" }
        let elapsed = periodElapsedPercent(start: start, end: end)
        var bits: [String] = []
        if let elapsed {
            bits.append("🕐 \(Int(elapsed))%")
        }
        bits.append(countdown)
        if countdown != "now", let detail = resetDetail(for: end, style: style) {
            bits.append(detail)
        }
        let body = "(\(bits.joined(separator: ", ")))"
        let emoji = paceEmoji(spent: spentPercent, elapsed: elapsed)
        if emoji.isEmpty {
            return "  \(body)"
        }
        return "  \(body) \(emoji)"
    }

    // MARK: - Title assembly (matches Alfred ``title`` field)

    public static func titleLine(
        label: String,
        percent: Double?,
        suffix: String
    ) -> String {
        "\(label)  \(bar(percent: percent))  \(percentString(percent))\(suffix)"
    }

    // MARK: - Watch compact presentation

    /// Five-slot meter for Watch rows (same green→yellow→red thresholds).
    public static func compactBar(percent: Double?) -> String {
        bar(percent: percent, width: 5)
    }

    public static func watchRowLine(row: OverviewRow) -> String {
        let pct = percentString(row.percentUsed)
        return "\(row.id.shortLabel)  \(compactBar(percent: row.percentUsed))  \(pct)"
    }

    public static func watchComplicationPercent(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value >= 9.95 {
            return String(format: "%.0f%%", value)
        }
        return String(format: "%.1f%%", value)
    }

    // MARK: - Date parsing (Cursor billing / Claude resets)

    public static func parseResetDate(raw: Any?, epoch: Int? = nil) -> Date? {
        if let epoch {
            return Date(timeIntervalSince1970: TimeInterval(epoch))
        }
        guard let raw else { return nil }
        if let ms = raw as? Int {
            return Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
        }
        if let ms = raw as? Double {
            return Date(timeIntervalSince1970: ms / 1000.0)
        }
        if let str = raw as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.allSatisfy(\.isNumber), let ms = Double(trimmed) {
                return Date(timeIntervalSince1970: ms / 1000.0)
            }
            let iso = trimmed.replacingOccurrences(of: "Z", with: "+00:00")
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: iso) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: iso)
        }
        return nil
    }
}
