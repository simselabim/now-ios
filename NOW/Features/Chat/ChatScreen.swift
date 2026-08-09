import SwiftUI

struct ChatScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var draft = ""

    private var activePlan: Plan { appState.activeMatch?.profile.plan ?? .coffee }
    private var suggestion: MeetingSuggestion { activePlan.primaryMeetingSuggestion }
    private var isExtendedForTomorrow: Bool {
        appState.activeMatch?.tomorrowExtension.status == .accepted
    }

    var body: some View {
        ZStack(alignment: .top) {
            NOWColor.laCream.ignoresSafeArea()
            LATopStripe()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    NOWBackButton {
                        appState.showActiveMatchMap()
                    }

                    Group {
                        if let profile = appState.activeMatch?.profile {
                            ProfilePhoto(profile: profile)
                        } else {
                            BundlePhoto(name: NOWPhoto.person)
                        }
                    }
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
                        if let loopURL = appState.theirFirstLoopURL {
                            LoopMessage(url: loopURL, sender: .them)
                        }

                        if let loopURL = appState.myFirstLoopURL {
                            LoopMessage(url: loopURL, sender: .me)
                        }

                        ForEach(appState.messages) { message in
                            Bubble(text: message.text, sender: message.sender)
                        }

                        if let match = appState.activeMatch {
                            TomorrowExtensionCard(
                                match: match,
                                isLoading: appState.isLoading,
                                request: appState.requestTomorrowExtension,
                                accept: appState.acceptTomorrowExtension,
                                reject: appState.rejectTomorrowExtension
                            )
                        }

                        PlaceSuggestionCard(
                            suggestion: suggestion,
                            dateLabel: isExtendedForTomorrow ? "Tomorrow" : "Today"
                        ) {
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
    let url: URL
    let sender: MessageSender

    var body: some View {
        CircularLoopPlayer(
            url: url,
            diameter: 180,
            strokeColor: sender == .me ? NOWColor.laCoral : NOWColor.laOrange,
            lineWidth: 3,
            startsMuted: true,
            togglesAudioOnTap: true
        )
        .frame(maxWidth: .infinity, alignment: sender == .me ? .trailing : .leading)
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
    let dateLabel: String
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
                Text("\(dateLabel) \(suggestion.time) · 12 min walk for both")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NOWColor.inkSoft)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Button("Propose") {
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

private struct TomorrowExtensionCard: View {
    let match: Match
    let isLoading: Bool
    let request: () -> Void
    let accept: () -> Void
    let reject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(NOWColor.laBrown)
                Spacer()
            }

            Text(bodyText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(NOWColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            buttons
        }
        .padding(13)
        .background(NOWColor.surface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NOWColor.laBrown.opacity(0.18), lineWidth: 1)
        )
        .frame(maxWidth: 260, alignment: .leading)
    }

    @ViewBuilder
    private var buttons: some View {
        switch match.tomorrowExtension.status {
        case .none:
            Button("Keep for tomorrow") {
                request()
            }
            .disabled(isLoading)
            .buttonStyle(TomorrowPrimaryButtonStyle())
        case .proposed where match.tomorrowExtension.requestedByMe:
            Text("Waiting for \(match.profile.name)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(NOWColor.laBrown)
                .padding(.vertical, 8)
        case .proposed:
            HStack(spacing: 8) {
                Button("Accept") {
                    accept()
                }
                .disabled(isLoading)
                .buttonStyle(TomorrowPrimaryButtonStyle())

                Button("No") {
                    reject()
                }
                .disabled(isLoading)
                .buttonStyle(TomorrowSecondaryButtonStyle())
            }
        case .accepted:
            Text("Tomorrow plans are unlocked")
                .font(.caption.weight(.heavy))
                .foregroundStyle(NOWColor.laBrown)
                .padding(.vertical, 8)
        case .rejected, .expired, .cancelled:
            Text("Today rules still apply")
                .font(.caption.weight(.heavy))
                .foregroundStyle(NOWColor.laBrown)
                .padding(.vertical, 8)
        }
    }

    private var title: String {
        switch match.tomorrowExtension.status {
        case .none:
            return "Can't today?"
        case .proposed where match.tomorrowExtension.requestedByMe:
            return "Tomorrow request sent"
        case .proposed:
            return "\(match.profile.name) asked for tomorrow"
        case .accepted:
            return "Saved for tomorrow"
        case .rejected:
            return "Tomorrow declined"
        case .expired:
            return "Tomorrow expired"
        case .cancelled:
            return "Tomorrow cancelled"
        }
    }

    private var bodyText: String {
        switch match.tomorrowExtension.status {
        case .none:
            return "If today won't work, ask \(match.profile.name) to keep this match one more day."
        case .proposed where match.tomorrowExtension.requestedByMe:
            return "If they accept before sunset, you can set a meeting for tomorrow."
        case .proposed:
            return "Accept only if you still want to meet tomorrow. One extra day, no open-ended chat."
        case .accepted:
            return "You both kept this match. Set the place and time for tomorrow."
        case .rejected:
            return "The match stays on today's clock."
        case .expired:
            return "The request missed today's window."
        case .cancelled:
            return "The tomorrow request is no longer active."
        }
    }

    private var indicatorColor: Color {
        switch match.tomorrowExtension.status {
        case .accepted:
            return NOWColor.laGreen
        case .proposed:
            return NOWColor.laGold
        case .rejected, .expired, .cancelled:
            return NOWColor.laCoral
        case .none:
            return NOWColor.laOrange
        }
    }
}

private struct TomorrowPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.heavy))
            .foregroundStyle(NOWColor.surface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(NOWColor.laCoral.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(Capsule())
    }
}

private struct TomorrowSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.heavy))
            .foregroundStyle(NOWColor.laBrown)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(NOWColor.paper.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(Capsule())
    }
}
