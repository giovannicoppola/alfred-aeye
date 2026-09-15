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
        let snapshot = SnapshotStore.load() ?? (context.isPreview ? MockSnapshot.preview : .empty)
        completion(AeyeWidgetEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AeyeWidgetEntry>) -> Void) {
        let snapshot = SnapshotStore.load()
            ?? (context.isPreview ? MockSnapshot.preview : .empty)
        let entry = AeyeWidgetEntry(date: Date(), snapshot: snapshot)
        let next = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
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
        .description("Cursor, Claude & Grok Bot usage — same rows as the Alfred workflow.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct AeyeWidgetView: View {
    let snapshot: AeyeSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 8 : 5) {
            HStack {
                Text("🦉 Aeye")
                    .font(.caption.bold())
                if snapshot.isMockData {
                    Text("Sample")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.orange.opacity(0.18), in: Capsule())
                        .foregroundStyle(.orange)
                }
                Spacer()
                if snapshot.capturedAt > .distantPast {
                    Text(snapshot.capturedAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            let rows = snapshot.visibleRows
            if rows.isEmpty {
                Text("Open Aeye on iPhone to refresh")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows) { row in
                    WidgetRowView(row: row, compact: family == .systemMedium)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct WidgetRowView: View {
    let row: OverviewRow
    var compact: Bool = false

    private var textSize: CGFloat { compact ? 10 : 11 }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if row.isError {
                Text(row.titleLine)
                    .font(.system(size: textSize, design: .monospaced))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.red)
            } else {
                // Same split as the app: one wrapping line cannot hold the
                // label, ten meter slots, the percent and the reset detail.
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(row.label)
                        .font(.system(size: textSize, design: .monospaced).weight(.semibold))
                    Spacer(minLength: 2)
                    Text(AeyeFormatting.percentString(row.percentUsed))
                        .font(.system(size: textSize, design: .monospaced))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                Text(AeyeFormatting.bar(percent: row.percentUsed))
                    .font(.system(size: textSize + 1))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if !compact, let suffix = row.suffix {
                    let detail = AeyeFormatting.standaloneSuffix(suffix)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if !compact, !row.subtitle.isEmpty {
                Text(row.subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
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
