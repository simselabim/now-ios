import SwiftUI

@main
struct NOWApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environmentObject(appState)
                .task {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--auto-demo-login"),
                       !appState.isAuthenticated {
                        appState.login()
                    }
                    #endif
                }
        }
    }
}
