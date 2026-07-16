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
                    let arguments = ProcessInfo.processInfo.arguments
                    if let laScreen = arguments.first(where: { $0.hasPrefix("--la-screen=") }) {
                        appState.openLAStateForTesting(String(laScreen.dropFirst("--la-screen=".count)))
                    } else if arguments.contains("--auto-open-map"), !appState.isAuthenticated {
                        appState.loginAndOpenMapForTesting()
                    } else if arguments.contains("--auto-demo-login"), !appState.isAuthenticated {
                        appState.login()
                    }
                    #endif
                }
        }
    }
}
