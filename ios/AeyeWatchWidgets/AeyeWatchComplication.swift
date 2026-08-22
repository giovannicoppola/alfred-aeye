import WidgetKit
import SwiftUI

struct AeyeWatchEntry: TimelineEntry {
    let date: Date
    let snapshot: AeyeSnapshot
    let focusRow: OverviewRow?
}

struct AeyeWatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> AeyeWatchEntry {
        makeEntry(MockSnapshot.preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (AeyeWatchEntry) -> Void) {
        let snap = WatchSnapshotCache.load() ?? MockSnapshot.preview
        completion(makeEntry(snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AeyeWatchEntry>) -> Void) {
        let snap = WatchSnapshotCache.load() ?? MockSnapshot.preview
        let entry = makeEntry(snap)
        let next = Date().addingTimeInterval(AeyeFormatting.overviewCacheTTL)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry(_ snapshot: AeyeSnapshot) -> AeyeWatchEntry {
        let focus = snapshot.visibleRows.first
        return AeyeWatchEntry(date: Date(), snapshot: snapshot, focusRow: focus)
    }
}

struct AeyeWatchComplication: Widget {
    let kind: String = AeyeWatchKind.complicationIdentifier

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AeyeWatchProvider()) { entry in
            AeyeWatchComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Aeye")
        .description("Cursor & Claude usage at a glance.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner,
        ])
    }
}

struct AeyeWatchComplicationView: View {
    let entry: AeyeWatchEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            inline
        case .accessoryCorner:
            corner
        default:
            rectangular
        }
    }

    private var focus: OverviewRow? { entry.focusRow }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Text(focus?.id.shortLabel ?? "Aeye")
                    .font(.caption2)
                Text(AeyeFormatting.watchComplicationPercent(focus?.percentUsed))
                    .font(.headline.monospacedDigit())
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("🦉 Aeye")
                .font(.caption2.bold())
            ForEach(Array(entry.snapshot.visibleRows.prefix(2))) { row in
                HStack {
                    Text(row.id.shortLabel)
                    Spacer()
                    Text(AeyeFormatting.watchComplicationPercent(row.percentUsed))
                        .monospacedDigit()
                }
                .font(.caption2)
            }
        }
    }

    private var inline: some View {
        let row = focus
        return Text("Aeye \(row?.id.shortLabel ?? "") \(AeyeFormatting.watchComplicationPercent(row?.percentUsed))")
    }

    private var corner: some View {
        Text(AeyeFormatting.watchComplicationPercent(focus?.percentUsed))
            .font(.headline.monospacedDigit())
            .widgetLabel {
                Text(focus?.id.shortLabel ?? "Aeye")
            }
    }
}

#Preview("Circular", as: .accessoryCircular) {
    AeyeWatchComplication()
} timeline: {
    AeyeWatchEntry(date: .now, snapshot: MockSnapshot.preview, focusRow: MockSnapshot.preview.visibleRows.first)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    AeyeWatchComplication()
} timeline: {
    AeyeWatchEntry(date: .now, snapshot: MockSnapshot.preview, focusRow: MockSnapshot.preview.visibleRows.first)
}
