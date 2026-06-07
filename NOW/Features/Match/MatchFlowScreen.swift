import SwiftUI

struct MatchFlowScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if appState.meetingProposal?.status == .accepted {
            MeetingModeScreen()
        } else if appState.meetingProposal != nil {
            MeetingProposalScreen()
        } else if appState.chatUnlocked {
            ChatScreen()
        } else {
            FirstLoopScreen()
        }
    }
}
