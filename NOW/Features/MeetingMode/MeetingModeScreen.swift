import MapKit
import SwiftUI

struct MeetingModeScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showSafetyConfirmation = false

    private var meetingStatusText: String {
        switch appState.activeMatch?.meetingStatus {
        case .some(.onMyWay):
            return "Meeting mode · you're on your way"
        case .some(.arrived):
            return "Meeting mode · you arrived"
        case .some(.delayed):
            return "Meeting mode · running late"
        case .some(.none), nil:
            return "Meeting mode · keep each other updated"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
                if let proposal = appState.meetingProposal,
                   let coordinate = proposal.coordinate {
                    Annotation(proposal.placeName, coordinate: coordinate, anchor: .center) {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(NOWColor.surface)
                                    .frame(width: 42, height: 42)
                                Image(systemName: "star.fill")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(NOWColor.laOrange)
                            }
                            Text(proposal.placeName)
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(NOWColor.laBrown)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(NOWColor.surface)
                                .clipShape(Capsule())
                        }
                    }
                }

                if let currentCoordinate = appState.currentCoordinate {
                    Annotation("You", coordinate: currentCoordinate, anchor: .center) {
                        MeetingAvatar(photoURL: appState.myProfilePhotoURL, label: "You")
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .overlay(LAGradient.mapWash.blendMode(.multiply).allowsHitTesting(false))
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    LAPill(text: meetingStatusText, icon: nil, tint: NOWColor.laGreen)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 38)

                Spacer()
            }

            VStack(spacing: 12) {
                Capsule()
                    .fill(NOWColor.line)
                    .frame(width: 42, height: 4)
                    .padding(.top, 10)

                HStack(spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(NOWColor.laOrange)
                        .frame(width: 54, height: 54)
                        .background(NOWColor.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.meetingProposal?.placeName ?? "Meeting place")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(NOWColor.laBrown)
                        Text("\(appState.meetingProposal?.time ?? "Time pending") · public place")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NOWColor.inkSoft)
                            .lineLimit(2)
                    }

                    Spacer()
                }

                HStack(spacing: 8) {
                    MeetingStatusButton(title: "On my way", active: appState.activeMatch?.meetingStatus == .onMyWay, disabled: appState.isLoading) {
                        appState.updateMeetingStatus(.onMyWay)
                    }
                    MeetingStatusButton(title: "Arrived", active: appState.activeMatch?.meetingStatus == .arrived, disabled: appState.isLoading) {
                        appState.updateMeetingStatus(.arrived)
                    }
                    MeetingStatusButton(title: "Delayed", active: appState.activeMatch?.meetingStatus == .delayed, disabled: appState.isLoading) {
                        appState.updateMeetingStatus(.delayed)
                    }
                }

                HStack(spacing: 8) {
                    MeetingStatusButton(title: "Save my location", active: false, disabled: appState.isLoading) {
                        appState.saveMeetingLocation()
                    }
                    MeetingStatusButton(title: "Safety alert", active: false, disabled: appState.isLoading, danger: true) {
                        showSafetyConfirmation = true
                    }
                }

                if let safetyMessage = appState.safetyMessage {
                    Text(safetyMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NOWColor.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("We met ✓") {
                    appState.weMet()
                }
                .disabled(appState.isLoading)
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(14)
            .background(NOWColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: NOWColor.ink.opacity(0.14), radius: 22, x: 0, y: -8)
        }
        .alert("Record a safety alert?", isPresented: $showSafetyConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Record alert", role: .destructive) {
                appState.triggerSafetyAlert()
            }
        } message: {
            Text("NOW will record this alert on the backend. This does not contact emergency services.")
        }
    }
}

private struct MeetingAvatar: View {
    let photoURL: URL?
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            UserPhoto(url: photoURL)
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(Circle().stroke(NOWColor.surface, lineWidth: 3))
            Text(label)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(NOWColor.surface)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(NOWColor.laBrownSoft.opacity(0.9))
                .clipShape(Capsule())
        }
    }
}

private struct MeetingStatusButton: View {
    let title: String
    let active: Bool
    var disabled = false
    var danger = false
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .disabled(disabled)
            .font(.caption.weight(.heavy))
            .foregroundStyle(danger ? NOWColor.laCoral : NOWColor.laBrown)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(active ? NOWColor.laGold.opacity(0.52) : NOWColor.surface.opacity(disabled ? 0.62 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(danger ? NOWColor.laCoral : NOWColor.line, lineWidth: 1)
            )
    }
}
