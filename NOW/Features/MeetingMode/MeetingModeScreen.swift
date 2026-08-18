import MapKit
import SwiftUI

struct MeetingModeScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var walkingRoute: MKRoute?
    @State private var isLoadingRoute = false
    @State private var routeErrorMessage: String?
    @State private var routeRefreshToken = UUID()
    @State private var staleCheckDate = Date()
    @State private var didFitPartnerLocation = false
    @State private var panelHeight: CGFloat = 0
    @State private var panelDragStartHeight: CGFloat?

    private var visiblePartnerLocation: PartnerMeetingLocation? {
        guard let location = appState.otherMeetingLocation,
              location.expiresAt.map({ $0 > staleCheckDate }) ?? true else {
            return nil
        }
        return location
    }

    private var partnerLocationKey: String? {
        guard let location = visiblePartnerLocation else { return nil }
        return "\(location.coordinate.latitude)-\(location.coordinate.longitude)"
    }

    private var routeTaskID: String {
        guard let proposal = appState.meetingProposal,
              let coordinate = proposal.coordinate else {
            return "no-destination-\(routeRefreshToken.uuidString)"
        }

        return "\(proposal.id.uuidString)-\(coordinate.latitude)-\(coordinate.longitude)-\(routeRefreshToken.uuidString)"
    }

    private var meetingLocationTaskID: String {
        "\(appState.activeMatch?.id.uuidString ?? "no-match")-\(appState.meetingLocationConfig?.updateIntervalSeconds ?? 0)"
    }

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
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
                if let walkingRoute {
                    MapPolyline(walkingRoute.polyline)
                        .stroke(NOWColor.laCoral, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                }

                if let partnerLocation = visiblePartnerLocation {
                    MapCircle(
                        center: partnerLocation.coordinate,
                        radius: CLLocationDistance(partnerLocation.accuracyRadiusM)
                    )
                    .foregroundStyle(NOWColor.laCoral.opacity(0.12))
                    .stroke(NOWColor.laCoral.opacity(0.75), lineWidth: 2)

                    Annotation(
                        appState.activeMatch?.profile.name ?? "Meeting partner",
                        coordinate: partnerLocation.coordinate,
                        anchor: .center
                    ) {
                        MeetingAvatar(
                            photoURL: appState.activeMatch?.profile.mainPhotoURL,
                            label: "\(appState.activeMatch?.profile.name ?? "Partner") · approx."
                        )
                    }
                }

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

            VStack(spacing: 10) {
                Capsule()
                    .fill(NOWColor.line)
                    .frame(width: 42, height: 4)
                    .padding(.top, 10)
                    .contentShape(Rectangle().inset(by: -12))
                    .gesture(panelDragGesture(containerHeight: geometry.size.height))

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

                MeetingRouteSummary(
                    route: walkingRoute,
                    isLoading: isLoadingRoute,
                    errorMessage: routeErrorMessage,
                    retry: {
                        routeRefreshToken = UUID()
                    }
                )

                PartnerLocationSummary(
                    location: visiblePartnerLocation,
                    errorMessage: appState.meetingLocationError
                )

                ScrollViewReader { proxy in
                    ScrollView {
                        MatchChatTranscript()
                            .padding(.vertical, 4)
                        Color.clear
                            .frame(height: 1)
                            .id(MeetingModeChatAnchor.bottom)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear {
                        scrollChatToBottom(proxy, animated: false)
                    }
                    .onChange(of: appState.messages.map(\.id)) { _, _ in
                        scrollChatToBottom(proxy, animated: true)
                    }
                    .onChange(of: appState.isSendingMessage) { _, sending in
                        if !sending {
                            scrollChatToBottom(proxy, animated: true)
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                ChatMessageComposer { focused in
                    if focused {
                        withAnimation(.easeOut(duration: 0.22)) {
                            panelHeight = MeetingChatPanelMetrics.expandedHeight(
                                containerHeight: geometry.size.height
                            )
                        }
                    }
                }

                Button("We met ✓") {
                    appState.weMet()
                }
                .disabled(appState.isLoading)
                .buttonStyle(PrimaryButtonStyle())
                .frame(height: 48)
            }
            .padding(14)
            .frame(height: effectivePanelHeight(containerHeight: geometry.size.height))
            .background(NOWColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: NOWColor.ink.opacity(0.14), radius: 22, x: 0, y: -8)
            .onAppear {
                if panelHeight == 0 {
                    panelHeight = MeetingChatPanelMetrics.defaultHeight(
                        containerHeight: geometry.size.height
                    )
                }
            }
            .onChange(of: geometry.size.height) { _, newHeight in
                panelHeight = MeetingChatPanelMetrics.clampedHeight(
                    panelHeight,
                    containerHeight: newHeight
                )
            }
            }
        }
        .task(id: routeTaskID) {
            await loadWalkingRoute()
        }
        .task(id: meetingLocationTaskID) {
            await shareMeetingLocationWhileVisible()
        }
        .task {
            while !Task.isCancelled {
                staleCheckDate = Date()
                try? await Task.sleep(for: .seconds(5))
            }
        }
        .onChange(of: partnerLocationKey) { _, newValue in
            guard newValue != nil, !didFitPartnerLocation else { return }
            didFitPartnerLocation = true
            fitCameraToMeeting()
        }
    }

    private func effectivePanelHeight(containerHeight: CGFloat) -> CGFloat {
        let requestedHeight = panelHeight == 0
            ? MeetingChatPanelMetrics.defaultHeight(containerHeight: containerHeight)
            : panelHeight
        return MeetingChatPanelMetrics.clampedHeight(
            requestedHeight,
            containerHeight: containerHeight
        )
    }

    private func panelDragGesture(containerHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let startHeight = panelDragStartHeight
                    ?? effectivePanelHeight(containerHeight: containerHeight)
                panelDragStartHeight = startHeight
                panelHeight = MeetingChatPanelMetrics.clampedHeight(
                    startHeight - value.translation.height,
                    containerHeight: containerHeight
                )
            }
            .onEnded { _ in
                panelDragStartHeight = nil
            }
    }

    private func scrollChatToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        let scroll = {
            proxy.scrollTo(MeetingModeChatAnchor.bottom, anchor: .bottom)
        }
        if animated {
            withAnimation(.easeOut(duration: 0.2), scroll)
        } else {
            scroll()
        }
    }

    private func shareMeetingLocationWhileVisible() async {
        while !Task.isCancelled {
            await appState.publishMeetingLocation()
            guard let interval = appState.meetingLocationConfig?.updateIntervalSeconds else {
                return
            }
            do {
                try await Task.sleep(for: .seconds(interval))
            } catch {
                return
            }
        }
    }

    private func loadWalkingRoute() async {
        guard let destinationCoordinate = appState.meetingProposal?.coordinate else {
            walkingRoute = nil
            routeErrorMessage = "The meeting place does not have coordinates yet."
            return
        }

        isLoadingRoute = true
        routeErrorMessage = nil
        walkingRoute = nil
        defer { isLoadingRoute = false }

        do {
            let sourceCoordinate = try await appState.currentLocationForMeetingRoute()
            try Task.checkCancellation()

            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: sourceCoordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinate))
            request.transportType = .walking
            request.requestsAlternateRoutes = false

            let response = try await MKDirections(request: request).calculate()
            try Task.checkCancellation()

            guard let route = response.routes.first else {
                routeErrorMessage = "No walking route is available for this place."
                return
            }

            walkingRoute = route
            fitCameraToMeeting()
        } catch is CancellationError {
            return
        } catch let error as LocalizedError {
            routeErrorMessage = error.errorDescription ?? "Could not calculate a walking route."
        } catch {
            routeErrorMessage = "Could not calculate a walking route. Check your connection and try again."
        }
    }

    private func paddedMapRect(for rect: MKMapRect) -> MKMapRect {
        let horizontalPadding = max(rect.size.width * 0.18, 900)
        let verticalPadding = max(rect.size.height * 0.24, 900)

        return MKMapRect(
            x: rect.origin.x - horizontalPadding,
            y: rect.origin.y - verticalPadding,
            width: rect.size.width + horizontalPadding * 2,
            height: rect.size.height + verticalPadding * 2
        )
    }

    private func fitCameraToMeeting() {
        var rect = walkingRoute?.polyline.boundingMapRect ?? .null
        if let currentCoordinate = appState.currentCoordinate {
            rect = rect.union(mapRect(for: currentCoordinate))
        }
        if let destinationCoordinate = appState.meetingProposal?.coordinate {
            rect = rect.union(mapRect(for: destinationCoordinate))
        }
        if let partnerCoordinate = visiblePartnerLocation?.coordinate {
            rect = rect.union(mapRect(for: partnerCoordinate))
        }
        guard !rect.isNull else { return }
        cameraPosition = .rect(paddedMapRect(for: rect))
    }

    private func mapRect(for coordinate: CLLocationCoordinate2D) -> MKMapRect {
        let point = MKMapPoint(coordinate)
        return MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
    }
}

enum MeetingModeChatAnchor {
    static let bottom = "meeting-mode-chat-bottom"
}

enum MeetingChatPanelMetrics {
    static let minimumHeight: CGFloat = 390

    static func maximumHeight(containerHeight: CGFloat) -> CGFloat {
        max(minimumHeight, containerHeight * 0.84)
    }

    static func defaultHeight(containerHeight: CGFloat) -> CGFloat {
        clampedHeight(containerHeight * 0.64, containerHeight: containerHeight)
    }

    static func expandedHeight(containerHeight: CGFloat) -> CGFloat {
        maximumHeight(containerHeight: containerHeight)
    }

    static func clampedHeight(_ height: CGFloat, containerHeight: CGFloat) -> CGFloat {
        min(max(height, minimumHeight), maximumHeight(containerHeight: containerHeight))
    }
}

private struct PartnerLocationSummary: View {
    let location: PartnerMeetingLocation?
    let errorMessage: String?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: location == nil ? "location.slash" : "location.circle.fill")
                .foregroundStyle(NOWColor.laCoral)
            VStack(alignment: .leading, spacing: 2) {
                if let location {
                    Text("Partner location · approximate")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(NOWColor.laBrown)
                    Text("Shown within \(location.accuracyRadiusM) m for privacy")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(NOWColor.inkSoft)
                } else {
                    Text(errorMessage ?? "Waiting for your partner's live location…")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NOWColor.inkSoft)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(NOWColor.paper)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MeetingRouteSummary: View {
    let route: MKRoute?
    let isLoading: Bool
    let errorMessage: String?
    let retry: () -> Void

    var body: some View {
        Group {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Calculating walking route…")
                }
                .accessibilityElement(children: .combine)
            } else if let route {
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(NOWColor.laOrange)
                    Text(routeSummary(route))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(NOWColor.laBrown)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Walking route, \(routeSummary(route))")
            } else if let errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(NOWColor.laOrange)
                    Text(errorMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NOWColor.inkSoft)
                    Spacer(minLength: 0)
                    Button("Retry", action: retry)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(NOWColor.laCoral)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(NOWColor.paper)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func routeSummary(_ route: MKRoute) -> String {
        let distance = formattedDistance(route.distance)
        let minutes = max(1, Int((route.expectedTravelTime / 60).rounded()))
        let arrival = Date()
            .addingTimeInterval(route.expectedTravelTime)
            .formatted(date: .omitted, time: .shortened)
        return "\(distance) · \(minutes) min walk · arrive \(arrival)"
    }

    private func formattedDistance(_ meters: CLLocationDistance) -> String {
        if meters < 1_000 {
            return "\(Int(meters.rounded())) m"
        }

        return String(format: "%.1f km", meters / 1_000)
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
