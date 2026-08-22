import SwiftUI
import WatchConnectivity

@main
struct AeyeWatchApp: App {
    @State private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(model)
        }
    }
}
