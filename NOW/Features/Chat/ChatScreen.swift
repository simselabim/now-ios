import SwiftUI

struct ChatScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                NOWBackButton {
                    appState.goBackForTesting()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(appState.activeMatch?.profile.name ?? "Today chat")
                        .font(.system(size: 34, weight: .black))
                    Text("Coffee today · chat closes tonight")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NOWColor.inkSoft)
                }
                Spacer()
                NOWChip(text: "Now", active: true)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if appState.messages.isEmpty {
                        Bubble(text: "Still good for coffee around 13:30?", sender: .them)
                        Bubble(text: "Yes. Somewhere near the park?", sender: .me)
                    }

                    ForEach(appState.messages) { message in
                        Bubble(text: message.text, sender: message.sender)
                    }

                    PlaceSuggestionCard {
                        appState.createMeetingProposal()
                    }

                    Text("Use the app confirmation for place and time. It keeps the meeting clear.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NOWColor.inkSoft)
                        .padding(.top, 2)
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 10) {
                TextField("Write a message", text: $draft)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(NOWColor.paper)
                    .clipShape(Capsule())

                Button {
                    appState.sendMessage(draft)
                    draft = ""
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(NOWColor.ink)
                        .clipShape(Circle())
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
    }
}

private struct Bubble: View {
    let text: String
    let sender: MessageSender

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(sender == .me ? NOWColor.ink : NOWColor.slate)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(sender == .me ? NOWColor.lime : NOWColor.paper)
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: sender == .me ? .trailing : .leading)
    }
}

private struct PlaceSuggestionCard: View {
    let confirm: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            BundlePhoto(name: NOWPhoto.cafeMeet)
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("Cafe Luna")
                    .font(.headline.weight(.black))
                    .foregroundStyle(NOWColor.ink)
                Text("13:30 today · public place · both need to approve.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NOWColor.inkSoft)
                    .lineLimit(2)

                Button("Confirm place") {
                    confirm()
                }
                .font(.caption.weight(.black))
                .foregroundStyle(NOWColor.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(NOWColor.lime)
                .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(NOWColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(NOWColor.line, lineWidth: 1)
        )
    }
}
