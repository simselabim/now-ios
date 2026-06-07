import SwiftUI

struct ChatScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Temporary chat")
                .font(.largeTitle.weight(.bold))

            Text("Chat closes after We Met, cancel, or tonight. Confirm place and time through NOW.")
                .font(.footnote)
                .foregroundStyle(NOWColor.inkSoft)
                .padding(10)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(appState.messages) { message in
                        Text(message.text)
                            .padding(10)
                            .foregroundStyle(message.sender == .me ? .white : NOWColor.ink)
                            .background(message.sender == .me ? NOWColor.teal : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(maxWidth: .infinity, alignment: message.sender == .me ? .trailing : .leading)
                    }
                }
            }

            HStack {
                TextField("Write about today's meeting", text: $draft)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    appState.sendMessage(draft)
                    draft = ""
                }
            }

            Button("Suggest place and time") {
                appState.createMeetingProposal()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
    }
}
