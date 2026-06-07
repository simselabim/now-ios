import SwiftUI

struct FirstLoopScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let match = appState.activeMatch {
                Text("One live match")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NOWColor.teal)

                Text("Send first loop.")
                    .font(.largeTitle.weight(.bold))

                Text("Discovery is paused. Both people send a short loop before chat unlocks.")
                    .foregroundStyle(NOWColor.inkSoft)

                HStack {
                    Circle()
                        .fill(NOWColor.coral)
                        .frame(width: 54, height: 54)
                        .overlay(Text(String(match.profile.name.prefix(1))).foregroundStyle(.white).font(.headline))
                    VStack(alignment: .leading) {
                        Text("\(match.profile.name), \(match.profile.age)")
                            .font(.headline)
                        Text("\(match.profile.plan.rawValue) · \(match.profile.intent.rawValue) · ready today")
                            .font(.subheadline)
                            .foregroundStyle(NOWColor.inkSoft)
                    }
                }
                .padding()
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Button("Record mock first loop") {
                    appState.sendFirstLoop()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Cancel match") {
                    appState.cancelMatch()
                }
                .buttonStyle(DangerButtonStyle())
            }
            Spacer()
        }
        .padding(20)
    }
}
