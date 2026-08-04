import SwiftUI

struct AppRouter: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            Group {
                if !appState.didAttemptSessionRestore {
                    ProgressView("Restoring session…")
                        .tint(NOWColor.lime)
                } else if !appState.isAuthenticated {
                    WelcomeScreen()
                } else if !appState.isProfileComplete {
                    CreateProfileScreen()
                } else if appState.showHistory {
                    HistoryScreen()
                } else if appState.activeMatch != nil {
                    MatchFlowScreen()
                } else if appState.selectedPoint != nil {
                    ProfilePreviewScreen()
                } else if !appState.isOnline {
                    GoOnlineScreen()
                } else {
                    DiscoveryMapScreen()
                }
            }
            .background(NOWColor.paper.ignoresSafeArea())
        }
    }
}
