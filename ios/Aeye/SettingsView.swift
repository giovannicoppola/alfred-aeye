import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var cursorToken = ""
    @State private var claudeToken = ""
    @State private var visibility: RowVisibility = SnapshotStore.loadVisibility()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Credentials stay in the iOS Keychain on your device. There is no Aeye account or backend.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Cursor") {
                    SecureField("WorkosCursorSessionToken", text: $cursorToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("From cursor.com → DevTools → Application → Cookies, or export from the Cursor Mac app session.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Claude") {
                    SecureField("Claude Code OAuth token", text: $claudeToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("OAuth access token from Claude Code sign-in. Percentages are labeled experimental (same as the Alfred workflow).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Visible rows") {
                    Toggle("Composer / Auto", isOn: $visibility.cursorAuto)
                    Toggle("Other models", isOn: $visibility.cursorOther)
                    Toggle("Hourly (5h)", isOn: $visibility.claudeHourly)
                    Toggle("Weekly", isOn: $visibility.claudeWeekly)
                }

                Section {
                    Button("Save & Refresh") {
                        model.saveCursorToken(cursorToken)
                        model.saveClaudeToken(claudeToken)
                        model.updateVisibility(visibility)
                        dismiss()
                    }
                    .disabled(visibility.enabledRows.isEmpty)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                cursorToken = model.credentials.cursorSessionToken ?? ""
                claudeToken = model.credentials.claudeOAuthToken ?? ""
                visibility = model.visibility
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppModel())
}
