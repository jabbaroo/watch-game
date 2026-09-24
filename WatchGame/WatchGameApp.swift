import SwiftUI

@main
struct WatchGameApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(environment)
        }
    }
}
