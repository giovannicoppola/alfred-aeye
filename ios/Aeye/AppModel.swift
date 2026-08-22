import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class AppModel {
    var snapshot: AeyeSnapshot = SnapshotStore.load() ?? MockSnapshot.preview
    var visibility: RowVisibility = SnapshotStore.loadVisibility()
    var isRefreshing = false
    var lastError: String?

    var credentials = CredentialsStore()

    private let service = AeyeService()

    init() {
        WatchBridge.shared.activate()
    }

    func refresh(force: Bool = false) async {
        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }

        let result = await service.fetchOverview(visibility: visibility, forceRefresh: force)
        snapshot = result
        WidgetCenter.shared.reloadTimelines(ofKind: AeyeWidgetKind.identifier)
        WatchBridge.shared.send(snapshot: result)
    }

    func saveCursorToken(_ token: String) {
        credentials.cursorSessionToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func saveClaudeToken(_ token: String) {
        credentials.claudeOAuthToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func updateVisibility(_ visibility: RowVisibility) {
        self.visibility = visibility
        SnapshotStore.saveVisibility(visibility)
        Task { await refresh(force: true) }
    }
}
