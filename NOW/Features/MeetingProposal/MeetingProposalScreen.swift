import SwiftUI

struct MeetingProposalScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Meeting proposal")
                .font(.largeTitle.weight(.bold))

            Text("For safety, confirm place and time through NOW.")
                .foregroundStyle(NOWColor.inkSoft)

            if let proposal = appState.meetingProposal {
                VStack(alignment: .leading, spacing: 10) {
                    Text(proposal.placeName)
                        .font(.title2.weight(.bold))
                    Text("Today · \(proposal.time)")
                        .foregroundStyle(NOWColor.inkSoft)
                    Text("Public place · mock proposal")
                        .font(.footnote)
                        .foregroundStyle(NOWColor.inkSoft)
                }
                .padding()
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button("Accept meeting") {
                appState.acceptMeetingProposal()
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Cancel match") {
                appState.cancelMatch()
            }
            .buttonStyle(DangerButtonStyle())

            Spacer()
        }
        .padding(20)
    }
}
