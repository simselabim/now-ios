import SwiftUI

@main
struct NOWApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environmentObject(appState)
                .preferredColorScheme(.light)
                .task {
                    await appState.restoreSession()
                    await appState.runServerSync()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        appState.applicationDidBecomeActive()
                    }
                }
        }
    }
}
