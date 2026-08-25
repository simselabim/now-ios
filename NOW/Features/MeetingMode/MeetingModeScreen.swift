import MapKit
import SwiftUI
import UIKit

struct MeetingModeScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var walkingRoute: MKRoute?
    @State private var isLoadingRoute = false
    @State private var routeErrorMessage: String?
    @State private var routeRefreshToken = UUID()
    @State private var staleCheckDate = Date()
    @State private var didFitPartnerLocation = false
    @State private var cameraPolicy = MeetingModeCameraPolicy()
    @State private var panelHeight: CGFloat = 0
    @State private var panelDragStartHeight: CGFloat?
    @State private var isPanelCollapsed = false
    @State private var panelHeightBeforeCollapse: CGFloat?
    @State private var isKeyboardVisible = false
    @State private var showCloseConfirmation = false
    @State private var loopViewer = MatchLoopViewerState()

    private var mapPresentation: MeetingModeMapPresentation {
        MeetingModeMapPresentation(
            userCoordinate: appState.currentCoordinate,
            partnerLocation: appState.otherMeetingLocation,
            meetingCoordinate: appState.meetingProposal?.coordinate,
            now: staleCheckDate
        )
    }

    private var visiblePartnerLocation: PartnerMeetingLocation? {
        mapPresentation.partnerLocation
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
                   let coordinate = mapPresentation.meetingCoordinate {
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

                if let currentCoordinate = mapPresentation.userCoordinate {
                    Annotation("You", coordinate: currentCoordinate, anchor: .center) {
                        MeetingAvatar(photoURL: appState.myProfilePhotoURL, label: "You")
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { _ in
                        cameraPolicy.recordUserAdjustment()
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { _ in
                        cameraPolicy.recordUserAdjustment()
                    }
            )
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
                Button {
                    togglePanel(containerHeight: geometry.size.height)
                } label: {
                    VStack(spacing: 5) {
                        Capsule()
                            .fill(NOWColor.line)
                            .frame(width: 42, height: 4)
                        Image(systemName: isPanelCollapsed ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.black))
                            .foregroundStyle(NOWColor.laBrown)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPanelCollapsed ? "Show meeting chat" : "Hide meeting chat")
                .accessibilityHint("Shows or hides the panel so you can view the map")
                .gesture(
                    isPanelCollapsed
                        ? nil
                        : panelDragGesture(containerHeight: geometry.size.height)
                )

                if !isPanelCollapsed {
                    Group {
                        if MeetingInformationVisibilityPolicy.showsInformation(
                            panelHeight: effectivePanelHeight(containerHeight: geometry.size.height),
                            containerHeight: geometry.size.height,
                            isPanelCollapsed: isPanelCollapsed,
                            isKeyboardVisible: isKeyboardVisible
                        ) {
                            Group {
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
                            }
                            .transition(.opacity)
                        }

                        ScrollViewReader { proxy in
                            ScrollView {
                                MatchChatTranscript { slot in
                                    loopViewer.open(slot)
                                }
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

                        meetingActionRow
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(14)
            .frame(height: panelContainerHeight(containerHeight: geometry.size.height))
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
            .onChange(of: geometry.size.height) { oldHeight, newHeight in
                panelHeight = MeetingInformationVisibilityPolicy.adjustedPanelHeight(
                    panelHeight,
                    oldContainerHeight: oldHeight,
                    newContainerHeight: newHeight
                )
            }

            if let selection = loopViewer.selection,
               let url = loopURL(for: selection.slot) {
                ExpandedMatchLoopViewer(
                    url: url,
                    label: loopLabel(for: selection.slot),
                    strokeColor: selection.slot == .mine ? NOWColor.laCoral : NOWColor.laOrange,
                    playbackID: selection.playbackID
                ) {
                    loopViewer.close()
                }
                .zIndex(20)
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.18)) {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.18)) {
                isKeyboardVisible = false
            }
        }
        .onChange(of: appState.activeMatch?.id) { _, _ in
            loopViewer.close()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                loopViewer.close()
            }
        }
        .onDisappear {
            loopViewer.close()
        }
        .alert("Close this match?", isPresented: $showCloseConfirmation) {
            Button("Keep waiting", role: .cancel) {}
            Button("Close match", role: .destructive) {
                appState.cancelMatch()
            }
        } message: {
            Text("This ends the match and releases both of you. Your meeting confirmation will not complete it.")
        }
    }

    private func loopURL(for slot: MatchLoopSlot) -> URL? {
        switch slot {
        case .mine:
            appState.myFirstLoopURL
        case .theirs:
            appState.theirFirstLoopURL
        }
    }

    private func loopLabel(for slot: MatchLoopSlot) -> String {
        switch slot {
        case .mine:
            "Your loop"
        case .theirs:
            "\(appState.activeMatch?.profile.name ?? "Their") loop"
        }
    }

    private var meetingActionRow: some View {
        GeometryReader { geometry in
            let frames = MeetingModeActionLayout.buttonFrames(
                availableWidth: geometry.size.width
            )

            HStack(spacing: MeetingModeActionLayout.horizontalSpacing) {
                Group {
                    if appState.activeMatch?.hasConfirmedWeMet == true {
                        WeMetConfirmedStatus()
                    } else {
                        Button("We met ✓") {
                            appState.weMet()
                        }
                        .disabled(appState.isLoading)
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("meeting-mode-we-met")
                    }
                }
                .frame(width: frames.leading.width)

                Button("Close match") {
                    showCloseConfirmation = true
                }
                .disabled(appState.isCancellingMatch || appState.isLoading)
                .buttonStyle(DangerButtonStyle())
                .frame(width: frames.trailing.width)
                .accessibilityIdentifier("meeting-mode-close-kindly")
                .accessibilityHint("Ends this match for both participants")
            }
            .accessibilityIdentifier("meeting-mode-action-row")
        }
        .frame(height: MeetingModeActionLayout.actionRowHeight)
        .padding(.top, MeetingModeActionLayout.composerGap)
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

    private func panelContainerHeight(containerHeight: CGFloat) -> CGFloat {
        isPanelCollapsed
            ? MeetingChatPanelMetrics.collapsedHeight
            : effectivePanelHeight(containerHeight: containerHeight)
    }

    private func togglePanel(containerHeight: CGFloat) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if isPanelCollapsed {
                panelHeight = panelHeightBeforeCollapse
                    ?? MeetingChatPanelMetrics.defaultHeight(containerHeight: containerHeight)
                isPanelCollapsed = false
            } else {
                panelHeightBeforeCollapse = effectivePanelHeight(containerHeight: containerHeight)
                dismissKeyboard()
                isPanelCollapsed = true
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
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
        guard cameraPolicy.allowsAutomaticFit else { return }

        var rect = walkingRoute?.polyline.boundingMapRect ?? .null
        if let currentCoordinate = mapPresentation.userCoordinate {
            rect = rect.union(mapRect(for: currentCoordinate))
        }
        if let destinationCoordinate = mapPresentation.meetingCoordinate {
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

enum MeetingModeActionLayout {
    static let horizontalSpacing: CGFloat = 10
    static let actionRowHeight: CGFloat = 58
    static let composerGap: CGFloat = 30

    static func buttonFrames(availableWidth: CGFloat) -> (leading: CGRect, trailing: CGRect) {
        let buttonWidth = max(0, (availableWidth - horizontalSpacing) / 2)
        let leading = CGRect(x: 0, y: 0, width: buttonWidth, height: actionRowHeight)
        let trailing = CGRect(
            x: buttonWidth + horizontalSpacing,
            y: 0,
            width: buttonWidth,
            height: actionRowHeight
        )
        return (leading, trailing)
    }
}

private struct WeMetConfirmedStatus: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2.weight(.black))
            VStack(alignment: .leading, spacing: 2) {
                Text("Confirmed")
                    .font(.headline.weight(.black))
                Text("Waiting for the other person")
                    .font(.caption.weight(.bold))
            }
            Spacer()
        }
        .foregroundStyle(NOWColor.laBrown)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(NOWColor.laGreen.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NOWColor.laGreen, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Meeting confirmed. Waiting for the other person.")
    }
}

enum MeetingChatPanelMetrics {
    static let collapsedHeight: CGFloat = 62
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

enum MeetingInformationVisibilityPolicy {
    private static let expandedTolerance: CGFloat = 1

    static func showsInformation(
        panelHeight: CGFloat,
        containerHeight: CGFloat,
        isPanelCollapsed: Bool,
        isKeyboardVisible: Bool
    ) -> Bool {
        !isPanelCollapsed
            && !isKeyboardVisible
            && isFullyExpanded(panelHeight: panelHeight, containerHeight: containerHeight)
    }

    static func adjustedPanelHeight(
        _ panelHeight: CGFloat,
        oldContainerHeight: CGFloat,
        newContainerHeight: CGFloat
    ) -> CGFloat {
        let resolvedHeight = panelHeight == 0
            ? MeetingChatPanelMetrics.defaultHeight(containerHeight: oldContainerHeight)
            : panelHeight

        if isFullyExpanded(
            panelHeight: resolvedHeight,
            containerHeight: oldContainerHeight
        ) {
            return MeetingChatPanelMetrics.expandedHeight(containerHeight: newContainerHeight)
        }

        return MeetingChatPanelMetrics.clampedHeight(
            resolvedHeight,
            containerHeight: newContainerHeight
        )
    }

    private static func isFullyExpanded(
        panelHeight: CGFloat,
        containerHeight: CGFloat
    ) -> Bool {
        abs(
            panelHeight
                - MeetingChatPanelMetrics.expandedHeight(containerHeight: containerHeight)
        ) <= expandedTolerance
    }
}

struct MeetingModeMapPresentation {
    let userCoordinate: CLLocationCoordinate2D?
    let partnerLocation: PartnerMeetingLocation?
    let meetingCoordinate: CLLocationCoordinate2D?

    init(
        userCoordinate: CLLocationCoordinate2D?,
        partnerLocation: PartnerMeetingLocation?,
        meetingCoordinate: CLLocationCoordinate2D?,
        now: Date
    ) {
        self.userCoordinate = userCoordinate
        self.partnerLocation = partnerLocation?.isFresh(at: now) == true ? partnerLocation : nil
        self.meetingCoordinate = meetingCoordinate
    }

    var markerCount: Int {
        [userCoordinate, partnerLocation?.coordinate, meetingCoordinate]
            .compactMap { $0 }
            .count
    }

    var partnerAccuracyRadiusM: Int? {
        partnerLocation?.accuracyRadiusM
    }
}

struct MeetingModeCameraPolicy {
    private(set) var hasUserAdjustedCamera = false

    var allowsAutomaticFit: Bool {
        !hasUserAdjustedCamera
    }

    mutating func recordUserAdjustment() {
        hasUserAdjustedCamera = true
    }
}

struct PartnerLocationSummary: View {
    let location: PartnerMeetingLocation?
    let errorMessage: String?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: location == nil ? "location.slash" : "location.circle.fill")
                .foregroundStyle(NOWColor.laCoral)
            if location != nil {
                Text("Partner location · approximate")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(NOWColor.laBrown)
            } else {
                Text(errorMessage ?? "Waiting for your partner's live location…")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NOWColor.inkSoft)
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
