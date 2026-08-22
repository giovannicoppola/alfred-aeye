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
                    }

                    Text(model.statusLine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if model.rows.isEmpty {
                        Text("No rows enabled on iPhone")
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

                    Text("Refresh from the iPhone app — Watch shows the last synced snapshot.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Aeye")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct WatchRowView: View {
    let row: OverviewRow

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.id.shortLabel)
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 4)
                Text(AeyeFormatting.watchComplicationPercent(row.percentUsed))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(row.isError ? .red : .primary)
            }

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
