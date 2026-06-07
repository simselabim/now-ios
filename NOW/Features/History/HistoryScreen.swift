import SwiftUI

struct HistoryScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("History")
                .font(.largeTitle.weight(.bold))

            Text("Completed meetings live here. Old chats do not reopen.")
                .foregroundStyle(NOWColor.inkSoft)

            Button("Back to today") {
                appState.closeHistory()
            }
            .buttonStyle(SecondaryButtonStyle())

            ForEach(appState.history) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.headline)
                    Text(item.detail)
                        .foregroundStyle(NOWColor.inkSoft)
                    Text(item.status)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NOWColor.teal)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Spacer()
        }
        .padding(20)
    }
}
