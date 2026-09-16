import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class AppModel {
    var snapshot: AeyeSnapshot = SnapshotStore.load() ?? .empty
    var visibility: RowVisibility = SnapshotStore.loadVisibility()
    var isRefreshing = false
    var lastError: String?
    var cursorConfigured = false
    var claudeConfigured = false
    /// Showing ``MockSnapshot`` instead of live numbers — see ``SampleDataMode``.
    var isSampleData = SampleDataMode.isEnabled

    var credentials = CredentialsStore()

    private let service = AeyeService()

    var needsSetup: Bool {
        !isSampleData && !cursorConfigured && !claudeConfigured
    }

    init() {
        // Report real credential state either way, so Settings never claims a
        // sign-in that did not happen just because the sample is on.
        cursorConfigured = credentials.hasCursor
        claudeConfigured = credentials.hasClaude
        WatchBridge.shared.activate()
        // The Watch can pull a fresh overview; this also runs when WatchConnectivity
        // wakes the app in the background. ``refresh`` answers with the sample
        // while sample mode is on, so one closure covers both.
        WatchBridge.shared.onRefreshRequested = { [weak self] in
            guard let self else { return .empty }
            await self.refresh(force: true)
            return self.snapshot
        }
        if isSampleData {
            applySampleData()
        }
    }

    func refresh(force: Bool = false) async {
        guard !isSampleData else {
            // Re-seed so the period countdowns advance with the clock.
            applySampleData()
            return
        }
        guard !needsSetup else {
            snapshot = .empty
            lastError = nil
            return
        }

        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }

        let result = await service.fetchOverview(visibility: visibility, forceRefresh: force)
        snapshot = result
        if lastError == nil, let errorRow = result.rows.first(where: \.isError) {
            lastError = errorRow.subtitle
        }
        WidgetCenter.shared.reloadTimelines(ofKind: AeyeWidgetKind.identifier)
        WatchBridge.shared.send(snapshot: result)
    }

    func saveCursorToken(_ token: String) throws {
        try credentials.saveCursorSessionToken(token)
        cursorConfigured = credentials.hasCursor
        // Signing in means you want your own numbers, not the demo.
        // The caller refreshes, so don't queue a second fetch.
        setSampleData(false, thenRefresh: false)
    }

    func clearCursorToken() throws {
        try credentials.saveCursorSessionToken("")
        cursorConfigured = credentials.hasCursor
    }

    func saveClaudeToken(_ token: String) throws {
        try credentials.saveClaudeOAuthToken(token)
        claudeConfigured = credentials.hasClaude
        setSampleData(false, thenRefresh: false)
    }

    func saveClaudeTokens(_ tokens: ClaudeOAuth.Tokens) throws {
        try credentials.saveClaudeTokens(tokens)
        claudeConfigured = credentials.hasClaude
        setSampleData(false, thenRefresh: false)
    }

    func clearClaudeToken() throws {
        try credentials.saveClaudeOAuthToken("")
        claudeConfigured = credentials.hasClaude
    }

    /// Turns the demo on or off, keeping the widget and the Watch in step —
    /// both read whatever snapshot the app last wrote.
    func setSampleData(_ enabled: Bool, thenRefresh: Bool = true) {
        guard enabled != isSampleData else { return }
        SampleDataMode.isEnabled = enabled
        isSampleData = enabled

        guard enabled else {
            // Clear the sample immediately; a real refresh may have nothing to
            // replace it with (no credentials), and stale fake numbers must not
            // linger on the Home Screen or the wrist.
            snapshot = .empty
            lastError = nil
            SnapshotStore.save(.empty)
            WidgetCenter.shared.reloadTimelines(ofKind: AeyeWidgetKind.identifier)
            WatchBridge.shared.send(snapshot: .empty)
            if thenRefresh {
                Task { await refresh(force: true) }
            }
            return
        }
        applySampleData()
    }

    private func applySampleData() {
        let sample = MockSnapshot.sample(
            visibility: visibility,
            markAsSample: !SampleDataMode.isForcedByLaunchArgument
        )
        snapshot = sample
        lastError = nil
        SnapshotStore.save(sample)
        WidgetCenter.shared.reloadTimelines(ofKind: AeyeWidgetKind.identifier)
        WatchBridge.shared.send(snapshot: sample)
    }

    func updateVisibility(_ visibility: RowVisibility) {
        self.visibility = visibility
        SnapshotStore.saveVisibility(visibility)
        Task { await refresh(force: true) }
    }
}
