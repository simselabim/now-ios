import MapKit
import SwiftUI

struct MeetingModeScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -8.667630, longitude: 115.139708),
            span: MKCoordinateSpan(latitudeDelta: 0.014, longitudeDelta: 0.014)
        )
    )

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
                if let proposal = appState.meetingProposal {
                    Annotation(proposal.placeName, coordinate: proposal.coordinate, anchor: .center) {
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

                Annotation("You", coordinate: CLLocationCoordinate2D(latitude: -8.668730, longitude: 115.138208), anchor: .center) {
                    MeetingAvatar(image: NOWPhoto.streetCoffee, label: "You · 6 min")
                }

                Annotation(appState.activeMatch?.profile.name ?? "Maya", coordinate: CLLocationCoordinate2D(latitude: -8.666330, longitude: 115.141608), anchor: .center) {
                    MeetingAvatar(image: NOWPhoto.person, label: "\(appState.activeMatch?.profile.name ?? "Maya") · 9 min")
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
                    BundlePhoto(name: NOWPhoto.cafeMeet)
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.meetingProposal?.placeName ?? "Dayglow · Sunset Blvd")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(NOWColor.laBrown)
                        Text("\(appState.meetingProposal?.time ?? "19:15") · public place · busy at this hour")
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
                    MeetingStatusButton(title: "Share my route", active: false, disabled: appState.isLoading) {}
                    MeetingStatusButton(title: "SOS", active: false, danger: true) {
                        appState.cancelMatch()
                    }
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
    }
}

private struct MeetingAvatar: View {
    let image: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            BundlePhoto(name: image)
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
