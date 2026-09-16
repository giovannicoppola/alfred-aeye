import SwiftUI

@main
struct AeyeWatchApp: App {
    @State private var model = WatchModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(model)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await model.refreshIfStale() }
                    }
                }
        }
    }
}
