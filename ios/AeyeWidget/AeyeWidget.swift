import WidgetKit
import SwiftUI

struct AeyeWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: AeyeSnapshot
}

struct AeyeTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> AeyeWidgetEntry {
        AeyeWidgetEntry(date: Date(), snapshot: MockSnapshot.preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (AeyeWidgetEntry) -> Void) {
        let snapshot = SnapshotStore.load() ?? MockSnapshot.preview
        completion(AeyeWidgetEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AeyeWidgetEntry>) -> Void) {
        Task {
            let stored = SnapshotStore.load()
            let snapshot: AeyeSnapshot
            if stored?.isMockData == true {
                snapshot = stored ?? MockSnapshot.preview
            } else if context.isPreview {
                snapshot = stored ?? MockSnapshot.preview
            } else {
                let service = AeyeService()
                snapshot = await service.fetchOverview(forceRefresh: true)
            }
            let entry = AeyeWidgetEntry(date: Date(), snapshot: snapshot)
            let next = Date().addingTimeInterval(AeyeFormatting.overviewCacheTTL)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

struct AeyeOverviewWidget: Widget {
    let kind: String = AeyeWidgetKind.identifier

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AeyeTimelineProvider()) { entry in
            AeyeWidgetView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Aeye")
        .description("Cursor & Claude usage — same four-row layout as the Alfred workflow.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct AeyeWidgetView: View {
    let snapshot: AeyeSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 8 : 6) {
            HStack {
                Text("🦉 Aeye")
                    .font(.caption.bold())
                Spacer()
                Text(snapshot.capturedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            let rows = snapshot.visibleRows
            if rows.isEmpty {
                Text("No rows enabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(displayRows(from: rows)) { row in
                    WidgetRowView(row: row, compact: family == .systemMedium)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func displayRows(from rows: [OverviewRow]) -> [OverviewRow] {
        switch family {
        case .systemMedium:
            return Array(rows.prefix(2))
        default:
            return rows
        }
    }
}

struct WidgetRowView: View {
    let row: OverviewRow
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(compactTitle)
                .font(.system(size: compact ? 10 : 11, design: .monospaced))
                .lineLimit(compact ? 2 : 3)
                .minimumScaleFactor(0.75)
                .foregroundStyle(row.isError ? .red : .primary)

            if !compact, !row.subtitle.isEmpty {
                Text(row.subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    /// Widget-friendly title: label + meter + pct + suffix on one line (matches Alfred).
    private var compactTitle: String {
        if row.isError { return row.titleLine }
        return row.titleLine
    }
}

#Preview(as: .systemLarge) {
    AeyeOverviewWidget()
} timeline: {
    AeyeWidgetEntry(date: .now, snapshot: MockSnapshot.preview)
}

#Preview(as: .systemMedium) {
    AeyeOverviewWidget()
} timeline: {
    AeyeWidgetEntry(date: .now, snapshot: MockSnapshot.preview)
}
