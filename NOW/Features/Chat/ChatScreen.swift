import CoreLocation
import SwiftUI

struct ChatScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var draft = ""
    @State private var meetingPlace: MeetingPlace?
    @State private var meetingTime = Date().addingTimeInterval(30 * 60)

    private var chatDayLabel: String {
        appState.activeMatch?.tomorrowExtension.status == .accepted ? "Until tomorrow" : "Today"
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

                    UserPhoto(url: appState.activeMatch?.profile.mainPhotoURL)
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(NOWColor.laOrange, lineWidth: 2))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.activeMatch?.profile.name ?? "Match")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(NOWColor.laBrown)
                        Text("Temporary chat")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(NOWColor.inkSoft)
                    }

                    Spacer()

                    Text(chatDayLabel)
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
                        HStack(alignment: .top, spacing: 16) {
                            LoopSlot(
                                url: appState.myFirstLoopURL,
                                label: "You",
                                sender: .me
                            )
                            LoopSlot(
                                url: appState.theirFirstLoopURL,
                                label: appState.activeMatch?.profile.name ?? "Them",
                                sender: .them
                            )
                        }
                        .frame(maxWidth: .infinity)

                        ForEach(appState.messages) { message in
                            Bubble(text: message.text, sender: message.sender)
                        }

                        if ProductFeatureAvailability.tomorrowExtension,
                           let match = appState.activeMatch {
                            TomorrowExtensionCard(
                                match: match,
                                isLoading: appState.isLoading,
                                request: appState.requestTomorrowExtension,
                                accept: appState.acceptTomorrowExtension,
                                reject: appState.rejectTomorrowExtension
                            )
                        }

                        MeetingProposalComposer(
                            place: $meetingPlace,
                            proposedTime: $meetingTime,
                            regionCenter: appState.currentCoordinate,
                            isLoading: appState.isLoading
                        ) {
                            guard let meetingPlace else { return }
                            appState.createMeetingProposal(place: meetingPlace, proposedTime: meetingTime)
                        }
                    }
                    .padding(.vertical, 8)
                }

                HStack(spacing: 10) {
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
        .onAppear {
            if meetingPlace == nil {
                meetingPlace = appState.preferredMeetingPlace
            }
        }
    }
}

private struct LoopSlot: View {
    let url: URL?
    let label: String
    let sender: MessageSender

    var body: some View {
        VStack(spacing: 7) {
            if let url {
                CircularLoopPlayer(
                    url: url,
                    diameter: 132,
                    strokeColor: strokeColor,
                    lineWidth: 3,
                    startsMuted: true,
                    togglesAudioOnTap: true
                )
            } else {
                ZStack {
                    Circle()
                        .fill(NOWColor.surface)
                        .overlay(
                            Circle()
                                .stroke(strokeColor.opacity(0.72), style: StrokeStyle(lineWidth: 3, dash: [8, 7]))
                        )

                    VStack(spacing: 6) {
                        ProgressView()
                            .tint(strokeColor)
                        Text("Waiting\nfor loop")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(NOWColor.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(width: 132, height: 132)
            }

            Text(label)
                .font(.caption.weight(.heavy))
                .foregroundStyle(NOWColor.laBrown)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var strokeColor: Color {
        sender == .me ? NOWColor.laCoral : NOWColor.laOrange
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

private struct MeetingProposalComposer: View {
    @Binding var place: MeetingPlace?
    @Binding var proposedTime: Date
    let regionCenter: CLLocationCoordinate2D?
    let isLoading: Bool
    let confirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Propose a real meeting place")
                .font(.headline.weight(.black))
                .foregroundStyle(NOWColor.laBrown)

            PlaceSearchField(selectedPlace: $place, regionCenter: regionCenter)

            DatePicker(
                "Date and time",
                selection: $proposedTime,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(.caption.weight(.semibold))

            Button("Propose", action: confirm)
                .disabled(place == nil || isLoading)
                .font(.caption.weight(.heavy))
                .foregroundStyle(NOWColor.surface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(NOWColor.laCoral)
                .clipShape(Capsule())
            }
        .padding(12)
        .background(NOWColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NOWColor.laBrown.opacity(0.22), lineWidth: 1)
        )
        .frame(maxWidth: 320, alignment: .leading)
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
