import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class WatchModel {
    var snapshot: AeyeSnapshot
    var statusLine: String = "Waiting for iPhone…"

    init() {
        let cached = WatchSnapshotCache.load()
        snapshot = cached ?? MockSnapshot.preview
        if cached != nil {
            statusLine = "Cached from iPhone"
        } else {
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
}
