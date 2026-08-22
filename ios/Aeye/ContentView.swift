import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    OverviewListView(rows: model.snapshot.visibleRows)
                    footer
                }
                .padding()
            }
            .navigationTitle("Aeye")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await model.refresh(force: true) }
                    } label: {
                        if model.isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(model.isRefreshing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                await model.refresh()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Keep an 👁️ on Cursor & Claude")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Same four-row layout as the Alfred workflow")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Text("Updated \(model.snapshot.capturedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text("Add the Aeye widget from your Home Screen for the same view at a glance.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct OverviewListView: View {
    let rows: [OverviewRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(rows) { row in
                OverviewRowView(row: row)
                if row.id != rows.last?.id {
                    Divider()
                }
            }
        }
    }
}

struct OverviewRowView: View {
    let row: OverviewRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.titleLine)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(row.isError ? .red : .primary)
                .textSelection(.enabled)

            if !row.subtitle.isEmpty {
                Text(row.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if let url = row.dashboardURL, !row.isError {
                Link("Open dashboard", destination: url)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
