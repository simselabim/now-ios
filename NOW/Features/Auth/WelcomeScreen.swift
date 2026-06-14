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

            if appState.isLoading {
                ProgressView()
                    .tint(NOWColor.teal)
            }

            if let error = appState.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(NOWColor.coral)
                    .padding(10)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button(appState.isLoading ? "Connecting..." : "Demo Login") {
                appState.login()
            }
            .disabled(appState.isLoading)
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
    }
}
