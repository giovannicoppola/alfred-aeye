import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class WatchModel {
    var snapshot: AeyeSnapshot
    var statusLine: String = "Waiting for iPhone…"
    var isRefreshing = false

    init() {
        if SampleDataMode.isForcedByLaunchArgument {
            snapshot = MockSnapshot.preview
            statusLine = "Synced from iPhone"
            return
        }
        if let cached = WatchSnapshotCache.load() {
            snapshot = cached
            statusLine = "Cached from iPhone"
        } else {
            snapshot = .empty
            statusLine = "Open Aeye on iPhone to sync"
        }

        WatchBridge.shared.onSnapshotReceived = { [weak self] snap in
            self?.snapshot = snap
            self?.statusLine = "Synced \(snap.capturedAt.formatted(date: .omitted, time: .shortened))"
            WidgetCenter.shared.reloadTimelines(ofKind: AeyeWatchKind.complicationIdentifier)
        }
        WatchBridge.shared.activate()
    }

    var rows: [OverviewRow] { snapshot.visibleRows }

    var hasSnapshot: Bool { snapshot.capturedAt > .distantPast }

    /// Pull automatically when the app comes forward on a snapshot that has gone stale.
    func refreshIfStale(olderThan maxAge: TimeInterval = 120) async {
        guard !hasSnapshot || Date().timeIntervalSince(snapshot.capturedAt) > maxAge else { return }
        await refresh()
    }

    /// Ask the iPhone for a fresh overview instead of waiting for it to push one.
    func refresh() async {
        guard !isRefreshing else { return }
        if SampleDataMode.isForcedByLaunchArgument { return }

        isRefreshing = true
        statusLine = "Asking iPhone…"
        defer { isRefreshing = false }

        switch await WatchBridge.shared.requestRefresh() {
        case .updated(let snap):
            // ``onSnapshotReceived`` already stored it; just confirm the time.
            snapshot = snap
            statusLine = "Updated \(snap.capturedAt.formatted(date: .omitted, time: .shortened))"
        case .queued:
            statusLine = "iPhone out of reach — will sync when connected"
        case .failed(let message):
            statusLine = message
        }
    }
}
