import SwiftUI

struct MeetingModeScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                NOWBackButton {
                    appState.goBackForTesting()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(appState.meetingProposal?.placeName ?? "Cafe Luna")
                        .font(.system(size: 34, weight: .black))
                    Text("\(appState.activeMatch?.profile.name ?? "They") approved · \(appState.meetingProposal?.time ?? "today")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NOWColor.inkSoft)
                }
                Spacer()
                NOWLogo(compact: true)
            }

            ZStack(alignment: .bottomLeading) {
                PhotoSurface(name: NOWPhoto.cafeTableBlur, height: 320, blur: 0.6, cornerRadius: 24)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Meet in a public place.")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(.white)
                    Text("Share only what you need. You can leave or report anytime.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(18)
            }

            NOWInfoCard {
                Text("On the way?")
                    .font(.headline.weight(.black))
                HStack(spacing: 8) {
                    ForEach([MeetingStatus.onMyWay, .arrived, .delayed]) { status in
                        Button(status == .onMyWay ? "I'm going" : status == .arrived ? "I'm here" : "Running late") {
                            appState.updateMeetingStatus(status)
                        }
                        .font(.caption.weight(.black))
                        .foregroundStyle(appState.activeMatch?.meetingStatus == status ? NOWColor.ink : NOWColor.inkSoft)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(appState.activeMatch?.meetingStatus == status ? NOWColor.lime : NOWColor.paper)
                        .clipShape(Capsule())
                    }
                }
            }

            Button("We met") {
                appState.weMet()
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Something's wrong") {
                appState.cancelMatch()
            }
            .buttonStyle(DangerButtonStyle())

            Spacer()
        }
        .padding(22)
    }
}
