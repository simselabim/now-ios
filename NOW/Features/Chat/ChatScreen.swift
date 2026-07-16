import SwiftUI

struct ChatScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var draft = ""

    private var activePlan: Plan { appState.activeMatch?.profile.plan ?? .coffee }
    private var suggestion: MeetingSuggestion { activePlan.primaryMeetingSuggestion }

    var body: some View {
        ZStack(alignment: .top) {
            NOWColor.laCream.ignoresSafeArea()
            LATopStripe()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    NOWBackButton {
                        appState.goBackForTesting()
                    }

                    BundlePhoto(name: NOWPhoto.person)
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(NOWColor.laOrange, lineWidth: 2))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.activeMatch?.profile.name ?? "Maya")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(NOWColor.laBrown)
                        Text("online until sunset · 19:58")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(NOWColor.inkSoft)
                    }

                    Spacer()

                    Text("1 h 08 m")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(NOWColor.laCoral)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(NOWColor.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(NOWColor.laCoral, lineWidth: 1.2))
                }
                .padding(.top, 24)

                Rectangle()
                    .fill(NOWColor.line.opacity(0.45))
                    .frame(height: 1)
                    .padding(.horizontal, -22)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        LoopMessage()

                        if appState.messages.isEmpty {
                            Bubble(text: "Okay that view! Matcha first, reservoir after?", sender: .me)
                            Bubble(text: "Deal. There's a spot on Sunset - best matcha east of the 101", sender: .them)
                        }

                        ForEach(appState.messages) { message in
                            Bubble(text: message.text, sender: message.sender)
                        }

                        PlaceSuggestionCard(suggestion: suggestion) {
                            appState.createMeetingProposal()
                        }
                    }
                    .padding(.vertical, 8)
                }

                HStack(spacing: 10) {
                    Button {
                        appState.sendMessage("Loop")
                    } label: {
                        Circle()
                            .fill(NOWColor.laCoral)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle()
                                    .fill(NOWColor.surface)
                                    .frame(width: 14, height: 14)
                            )
                    }
                    .buttonStyle(.plain)

                    TextField("Message...", text: $draft)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NOWColor.laBrown)
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(NOWColor.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(NOWColor.line, lineWidth: 1))

                    Button {
                        appState.sendMessage(draft)
                        draft = ""
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.headline.weight(.black))
                            .foregroundStyle(NOWColor.surface)
                            .frame(width: 48, height: 48)
                            .background(NOWColor.laBrown)
                            .clipShape(Circle())
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(14)
        }
    }
}

private struct LoopMessage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                BundlePhoto(name: NOWPhoto.person)
                    .frame(width: 84, height: 84)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(NOWColor.laOrange, lineWidth: 3))
                Image(systemName: "play.fill")
                    .font(.headline.weight(.black))
                    .foregroundStyle(NOWColor.surface)
            }
            Text("0:09")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(NOWColor.laGold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(NOWColor.laBrown.opacity(0.75))
                .clipShape(Capsule())
                .offset(x: 46, y: -22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Bubble: View {
    let text: String
    let sender: MessageSender

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(sender == .me ? NOWColor.surface : NOWColor.laBrown)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(sender == .me ? NOWColor.laBrown : NOWColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .frame(maxWidth: .infinity, alignment: sender == .me ? .trailing : .leading)
    }
}

private struct PlaceSuggestionCard: View {
    let suggestion: MeetingSuggestion
    let confirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BundlePhoto(name: NOWPhoto.cafeMeet)
                .frame(height: 108)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(suggestion.placeName)
                    .font(.headline.weight(.black))
                    .foregroundStyle(NOWColor.laBrown)
                Text("Today \(suggestion.time) · 12 min walk for both")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NOWColor.inkSoft)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Button("Accept") {
                        confirm()
                    }
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(NOWColor.surface)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(NOWColor.laCoral)
                    .clipShape(Capsule())

                    Button("Change") {}
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(NOWColor.laBrown)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(NOWColor.paper)
                        .clipShape(Capsule())
                }
            }
            .padding(12)
        }
        .background(NOWColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NOWColor.laBrown.opacity(0.22), lineWidth: 1)
        )
        .frame(maxWidth: 260, alignment: .leading)
    }
}
