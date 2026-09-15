import SwiftUI

struct WatchContentView: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("🦉 Aeye")
                            .font(.headline)
                        Spacer()
                        if model.snapshot.isMockData {
                            Text("Sample")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.orange.opacity(0.22), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }

                    statusRow

                    if model.rows.isEmpty {
                        Text(model.hasSnapshot
                             ? "No rows enabled on iPhone"
                             : "Open Aeye on iPhone to sync")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.rows) { row in
                            WatchRowView(row: row)
                            if row.id != model.rows.last?.id {
                                Divider().opacity(0.35)
                            }
                        }
                    }

                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(model.isRefreshing)
                    .padding(.top, 4)

                    Text("Pulls fresh numbers from the iPhone — it answers even in your pocket.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 4)
            }
            .refreshable {
                await model.refresh()
            }
            .navigationTitle("Aeye")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.isRefreshing)
                    .accessibilityLabel("Refresh from iPhone")
                }
            }
        }
    }

    /// Status plus a live-updating age so a stale snapshot is obvious at a glance.
    private var statusRow: some View {
        HStack(spacing: 4) {
            if model.isRefreshing {
                ProgressView()
                    .controlSize(.mini)
            }
            Text(model.statusLine)
            if model.hasSnapshot, !model.isRefreshing {
                Text("·")
                Text(model.snapshot.capturedAt, style: .relative)
                Text("ago")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

struct WatchRowView: View {
    let row: OverviewRow

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(row.id.provider)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(row.id.shortLabel)
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 4)
                Text(AeyeFormatting.watchComplicationPercent(row.percentUsed))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(row.isError ? .red : .primary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Text(AeyeFormatting.compactBar(percent: row.percentUsed))
                .font(.system(size: 10))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if !row.subtitle.isEmpty {
                Text(compactSubtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Prefer pace + spend bits; drop verbose plan prefixes when space is tight.
    private var compactSubtitle: String {
        if row.isError { return row.subtitle }
        // Keep dollar spend and pace-ish fragments; trim long plan= lines.
        let parts = row.subtitle
            .split(separator: "·")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("plan=") }
        if parts.isEmpty { return row.subtitle }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    WatchContentView()
        .environment(WatchModel())
}
