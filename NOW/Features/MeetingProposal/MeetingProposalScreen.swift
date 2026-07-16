import SwiftUI

struct MeetingProposalScreen: View {
    @EnvironmentObject private var appState: AppState

    private var isMyProposal: Bool {
        guard let currentUserId = appState.currentUserId,
              let proposerUserId = appState.meetingProposal?.proposerUserId else {
            return false
        }

        return currentUserId == proposerUserId
    }

    var body: some View {
        ZStack(alignment: .top) {
            NOWColor.laCream.ignoresSafeArea()
            LATopStripe()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    NOWBackButton {
                        appState.goBackForTesting()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Lock the place.")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(NOWColor.laBrown)
                        Text("Both of you should approve it here.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NOWColor.inkSoft)
                    }
                    Spacer()
                    LAPill(text: "19:15", icon: nil)
                }

                ZStack(alignment: .bottomLeading) {
                    PhotoSurface(name: NOWPhoto.cafeMeet, height: 320, blur: 0, cornerRadius: 24)
                    if let proposal = appState.meetingProposal {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(proposal.placeName)
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("\(proposal.dateLabel) · \(proposal.time) · public place · busy at this hour")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(18)
                    }
                }

                NOWInfoCard {
                    Text("Use NOW confirmation for place and time.")
                        .font(.headline.weight(.black))
                        .foregroundStyle(NOWColor.laBrown)
                    Text("It keeps the plan visible, clear, and easier to leave if anything feels off.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NOWColor.inkSoft)
                }

                if isMyProposal {
                    NOWInfoCard {
                        Text("Waiting for them.")
                            .font(.headline.weight(.black))
                            .foregroundStyle(NOWColor.laBrown)
                        Text("The place and time are saved. Meeting mode opens after they accept.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NOWColor.inkSoft)
                    }
                } else {
                    Button("Accept meeting") {
                        appState.acceptMeetingProposal()
                    }
                    .disabled(appState.isLoading)
                    .buttonStyle(PrimaryButtonStyle())
                }

                Button("Suggest another place") {
                    appState.suggestAnotherMeetingPlace()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Close kindly") {
                    appState.cancelMatch()
                }
                .buttonStyle(DangerButtonStyle())

                Spacer()
            }
            .padding(22)
            .padding(.top, 10)
        }
    }
}
