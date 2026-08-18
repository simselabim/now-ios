import MapKit
import SwiftUI

struct MeetingProposalScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var isEditingProposal = false
    @State private var editedPlace: MeetingPlace?
    @State private var editedTime = Date().addingTimeInterval(30 * 60)

    private var isMyProposal: Bool {
        guard let currentUserId = appState.currentUserId,
              let proposerUserId = appState.meetingProposal?.proposerUserId else {
            return false
        }

        return currentUserId == proposerUserId
    }

    var body: some View {
        ZStack(alignment: .top) {
            NOWColor.laCream.ignoresSafeArea()
            LATopStripe()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    NOWBackButton {
                        appState.showActiveMatchMap()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Lock the place.")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(NOWColor.laBrown)
                        Text("Both of you should approve it here.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NOWColor.inkSoft)
                    }
                    Spacer()
                    if let proposal = appState.meetingProposal {
                        LAPill(text: proposal.time, icon: nil)
                    }
                }

                if let proposal = appState.meetingProposal {
                    VStack(alignment: .leading, spacing: 10) {
                        if let coordinate = proposal.coordinate {
                            Map(
                                initialPosition: .region(
                                    MKCoordinateRegion(
                                        center: coordinate,
                                        latitudinalMeters: 1_200,
                                        longitudinalMeters: 1_200
                                    )
                                ),
                                interactionModes: [.pan, .zoom]
                            ) {
                                Marker(proposal.placeName, coordinate: coordinate)
                                    .tint(NOWColor.laCoral)
                            }
                            .frame(height: 190)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }

                        Text(proposal.placeName)
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(NOWColor.laBrown)
                        if let address = proposal.placeAddress {
                            Text(address)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NOWColor.inkSoft)
                        }
                        Text("\(proposal.dateLabel) · \(proposal.time)")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(NOWColor.laCoral)
                    }
                }

                NOWInfoCard {
                    Text("Use NOW confirmation for place and time.")
                        .font(.headline.weight(.black))
                        .foregroundStyle(NOWColor.laBrown)
                    Text("It keeps the plan visible, clear, and easier to leave if anything feels off.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NOWColor.inkSoft)
                }

                if isMyProposal {
                    NOWInfoCard {
                        Text("Waiting for them.")
                            .font(.headline.weight(.black))
                            .foregroundStyle(NOWColor.laBrown)
                        Text("The place and time are saved. Meeting mode opens after they accept.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NOWColor.inkSoft)
                    }
                } else {
                    Button("Accept meeting") {
                        appState.acceptMeetingProposal()
                    }
                    .disabled(appState.isLoading)
                    .buttonStyle(PrimaryButtonStyle())
                }

                if isEditingProposal {
                    VStack(alignment: .leading, spacing: 10) {
                        PlaceSearchField(
                            selectedPlace: $editedPlace,
                            regionCenter: appState.currentCoordinate
                        )
                        DatePicker(
                            "Date and time",
                            selection: $editedTime,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        Button("Save new proposal") {
                            guard let editedPlace else { return }
                            appState.updateMeetingProposal(place: editedPlace, proposedTime: editedTime)
                            isEditingProposal = false
                        }
                        .disabled(editedPlace == nil || appState.isLoading)
                        .buttonStyle(PrimaryButtonStyle())
                    }
                } else {
                    Button("Suggest another place") {
                        isEditingProposal = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Button("Close kindly") {
                    appState.cancelMatch()
                }
                .buttonStyle(DangerButtonStyle())

                }
                .padding(22)
                .padding(.top, 10)
            }
        }
        .onAppear {
            guard let proposal = appState.meetingProposal else { return }
            if let address = proposal.placeAddress, let coordinate = proposal.coordinate {
                editedPlace = MeetingPlace(
                    externalID: proposal.placeExternalID ?? MeetingPlace.legacyExternalID(
                        name: proposal.placeName,
                        address: address,
                        coordinate: coordinate
                    ),
                    name: proposal.placeName,
                    category: proposal.placeCategory,
                    address: address,
                    coordinate: coordinate
                )
            }
            if let proposedAt = proposal.proposedAt {
                editedTime = max(proposedAt, Date())
            }
        }
    }
}
