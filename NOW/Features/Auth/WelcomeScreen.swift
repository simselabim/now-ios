import SwiftUI

struct WelcomeScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            Text("NOW")
                .font(.system(size: 56, weight: .black))
                .foregroundStyle(NOWColor.ink)

            Text("Meet one real person nearby today.")
                .font(.title2.weight(.semibold))
                .foregroundStyle(NOWColor.ink)

            Text("No swipe deck. No backlog. One active match, one day, one decision.")
                .font(.body)
                .foregroundStyle(NOWColor.inkSoft)

            Spacer()

            Button("Register / Login") {
                appState.login()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
    }
}
