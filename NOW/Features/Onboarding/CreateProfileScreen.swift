import SwiftUI

struct CreateProfileScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Create profile")
                .font(.largeTitle.weight(.bold))

            Text("Add enough trust for someone to meet you today. Photos, short bio, interests, and an intro loop.")
                .foregroundStyle(NOWColor.inkSoft)

            VStack(alignment: .leading, spacing: 12) {
                RequirementRow(title: "At least one photo", done: true)
                RequirementRow(title: "Short profile", done: true)
                RequirementRow(title: "Intro loop", done: false)
            }
            .padding()
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            Button("Use mock profile") {
                appState.completeProfile()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
    }
}

private struct RequirementRow: View {
    let title: String
    let done: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(done ? NOWColor.teal : NOWColor.line)
                .frame(width: 10, height: 10)
            Text(title)
            Spacer()
        }
    }
}
