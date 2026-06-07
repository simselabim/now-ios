import SwiftUI

struct MeetingModeScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("On the way")
                .font(.largeTitle.weight(.bold))

            ZStack {
                NOWColor.tealPale
                Circle()
                    .fill(NOWColor.teal)
                    .frame(width: 26, height: 26)
                    .offset(x: -90, y: 70)
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white)
                    .frame(width: 136, height: 42)
                    .overlay(Text(appState.meetingProposal?.placeName ?? "Meeting point").font(.caption.weight(.bold)))
                    .offset(x: 54, y: -84)
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 8) {
                ForEach([MeetingStatus.onMyWay, .arrived, .delayed]) { status in
                    Button(status.rawValue) {
                        appState.updateMeetingStatus(status)
                    }
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(appState.activeMatch?.meetingStatus == status ? NOWColor.teal : NOWColor.inkSoft)
                    .background(appState.activeMatch?.meetingStatus == status ? NOWColor.tealPale : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Button("We met") {
                appState.weMet()
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Emergency") {}
                .buttonStyle(DangerButtonStyle())
        }
        .padding(20)
    }
}
