import MapKit
import SwiftUI

struct DiscoveryMapScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var venueSearchCenter: CLLocationCoordinate2D?
    @StateObject private var venueStore = NearbyVenueStore()

    var body: some View {
        LiveDiscoveryMap(
            points: mapPoints,
            venues: nearbyVenues,
            userCoordinate: appState.currentCoordinate,
            cameraPosition: $cameraPosition,
            activeMatchProfileId: appState.isViewingActiveMatchMap ? appState.activeMatch?.profile.id : nil,
            selectedVenueID: appState.preferredMeetingPlace?.id
        ) { point in
            appState.viewPoint(point)
        } onVenueTap: { venue in
            appState.selectPreferredMeetingPlace(venue)
        } onCameraSettled: { region in
            venueSearchCenter = region.center
            if !appState.isViewingActiveMatchMap {
                appState.rememberDiscoveryMapRegion(region)
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            restoreCameraPosition()
        }
        .onChange(of: cameraKey) { _, _ in
            reframeMap()
        }
        .task(id: venueSearchKey) {
            guard !appState.isViewingActiveMatchMap,
                  let coordinate = venueSearchCenter ?? appState.currentCoordinate else {
                venueStore.clear()
                return
            }

            try? await Task.sleep(for: .milliseconds(VenueDiscoveryConfig.searchDebounceMilliseconds))
            guard !Task.isCancelled else { return }
            await venueStore.load(around: coordinate)
        }
        .overlay(alignment: .top) {
            MapHeader(isLoading: appState.isLoading, isLockedToActiveMatch: appState.isViewingActiveMatchMap, discoveryRadiusM: appState.discoveryRadiusM, back: {
                if appState.isViewingActiveMatchMap {
                    appState.returnToActiveMatch()
                } else {
                    appState.goOffline()
                }
            }, recenter: {
                recenterOnUser()
            }, refresh: {
                appState.refreshActiveMatch()
                refreshVenues()
            }, goOffline: {
                appState.goOffline()
            })
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                if let error = appState.errorMessage {
                    Text(error)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NOWColor.coral)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NOWColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if let error = venueStore.errorMessage {
                    Text(error)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NOWColor.coral)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NOWColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if let venue = appState.preferredMeetingPlace,
                   !appState.isViewingActiveMatchMap {
                    SelectedVenueCard(venue: venue) {
                        appState.selectPreferredMeetingPlace(nil)
                    }
                }

                LAPill(
                    text: venueStore.isLoading
                        ? "Finding meeting places within \(VenueDiscoveryConfig.radiusLabel) of map center…"
                        : "Meeting places within \(VenueDiscoveryConfig.radiusLabel) of map center",
                    icon: nil
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private var mapPoints: [MapPoint] {
        appState.isViewingActiveMatchMap ? appState.activeMatchMapPoints : appState.visibleMapPoints
    }

    private var nearbyVenues: [MeetingPlace] {
        guard !appState.isViewingActiveMatchMap else { return [] }
        guard let selected = appState.preferredMeetingPlace,
              !venueStore.venues.contains(where: { $0.id == selected.id }) else {
            return venueStore.venues
        }
        return [selected] + venueStore.venues
    }

    private var venueSearchKey: String {
        guard let coordinate = venueSearchCenter ?? appState.currentCoordinate else { return "none" }
        return "\(rounded(coordinate.latitude)):\(rounded(coordinate.longitude)):\(appState.isViewingActiveMatchMap)"
    }

    private var cameraKey: String {
        let pointKey = mapPoints
            .map { "\($0.id.uuidString):\(rounded($0.approximateCoordinate.latitude)):\(rounded($0.approximateCoordinate.longitude))" }
            .joined(separator: "|")
        let userKey = appState.currentCoordinate.map { "\(rounded($0.latitude)):\(rounded($0.longitude))" } ?? "none"
        return "\(userKey)#\(pointKey)"
    }

    private func rounded(_ value: CLLocationDegrees) -> String {
        String(format: "%.5f", value)
    }

    private func recenterOnUser() {
        if let currentCoordinate = appState.currentCoordinate {
            let region = MKCoordinateRegion(
                center: currentCoordinate,
                latitudinalMeters: VenueDiscoveryConfig.initialViewportSpanM,
                longitudinalMeters: VenueDiscoveryConfig.initialViewportSpanM
            )
            withAnimation(.easeInOut(duration: 0.35)) {
                cameraPosition = .region(region)
            }
        } else {
            reframeMap()
        }
    }

    private func refreshVenues() {
        guard !appState.isViewingActiveMatchMap,
              let coordinate = venueSearchCenter ?? appState.currentCoordinate else {
            return
        }
        Task {
            await venueStore.reload(around: coordinate)
        }
    }

    private func restoreCameraPosition() {
        if appState.isViewingActiveMatchMap {
            venueSearchCenter = nil
            reframeMap()
            return
        }

        if let region = appState.discoveryMapRegion {
            venueSearchCenter = region.center
            cameraPosition = .region(region)
            return
        }

        venueSearchCenter = appState.currentCoordinate
        recenterOnUser()
    }

    private func reframeMap() {
        guard let region = MKCoordinateRegion.fitting(
            points: mapPoints,
            userCoordinate: appState.currentCoordinate
        ) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .region(region)
        }
    }
}

private struct MapHeader: View {
    let isLoading: Bool
    let isLockedToActiveMatch: Bool
    let discoveryRadiusM: Int?
    let back: () -> Void
    let recenter: () -> Void
    let refresh: () -> Void
    let goOffline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(NOWColor.surface)
                        .frame(width: 42, height: 42)
                        .background(NOWColor.laBrownSoft.opacity(0.92))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                NOWLogo(compact: true)

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(NOWColor.laOrange)
                        .padding(10)
                        .background(NOWColor.surface.opacity(0.9))
                        .clipShape(Circle())
                }

                Button {
                    recenter()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.caption.weight(.black))
                        .foregroundStyle(NOWColor.laBrown)
                        .frame(width: 42, height: 42)
                        .background(NOWColor.surface.opacity(0.9))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Center on me")

                Button {
                    refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.black))
                        .foregroundStyle(NOWColor.laBrown)
                        .frame(width: 42, height: 42)
                        .background(NOWColor.surface.opacity(0.9))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                if isLockedToActiveMatch {
                    Text("Read-only")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(NOWColor.surface)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(NOWColor.laBrownSoft.opacity(0.92))
                        .clipShape(Capsule())
                } else {
                    Button("Online") {
                        goOffline()
                    }
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(NOWColor.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(NOWColor.laOrange)
                    .clipShape(Capsule())
                }
            }

            LAPill(
                text: isLockedToActiveMatch
                    ? "Meeting mode · active match only"
                    : discoveryRadiusText,
                icon: nil
            )
        }
    }

    private var discoveryRadiusText: String {
        guard let discoveryRadiusM else {
            return "Discovering people nearby…"
        }
        if discoveryRadiusM.isMultiple(of: 1_000) {
            return "Discovering people within \(discoveryRadiusM / 1_000) km"
        }
        return "Discovering people within \(discoveryRadiusM) m"
    }
}

private struct LiveDiscoveryMap: View {
    let points: [MapPoint]
    let venues: [MeetingPlace]
    let userCoordinate: CLLocationCoordinate2D?
    @Binding var cameraPosition: MapCameraPosition
    let activeMatchProfileId: UUID?
    let selectedVenueID: String?
    let onTap: (MapPoint) -> Void
    let onVenueTap: (MeetingPlace) -> Void
    let onCameraSettled: (MKCoordinateRegion) -> Void

    var body: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate]) {
            if let userCoordinate {
                Annotation("You", coordinate: userCoordinate, anchor: .center) {
                    LAUserLocationMarker()
                }
            }

            ForEach(venues) { venue in
                Annotation(venue.name, coordinate: venue.coordinate, anchor: .bottom) {
                    Button {
                        onVenueTap(venue)
                    } label: {
                        LAVenueMarker(category: venue.category, isSelected: venue.id == selectedVenueID)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "Choose \(venue.name), \(venue.category.displayName), \(venue.address)"
                    )
                }
            }

            ForEach(points) { point in
                Annotation(point.profile.name, coordinate: point.approximateCoordinate, anchor: .center) {
                    Button {
                        onTap(point)
                    } label: {
                        LAMapPersonMarker(
                            point: point,
                            isCurrentMatch: point.profile.id == activeMatchProfileId,
                            isLocked: activeMatchProfileId != nil
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(activeMatchProfileId != nil && point.profile.id != activeMatchProfileId)
                    .accessibilityLabel("\(point.profile.name), \(point.profile.distance)")
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            onCameraSettled(context.region)
        }
        .tint(NOWColor.lime)
        .overlay(LAGradient.mapWash.blendMode(.multiply).allowsHitTesting(false))
        .overlay {
            Circle()
                .stroke(NOWColor.surface.opacity(0.42), style: StrokeStyle(lineWidth: 2, dash: [7, 7]))
                .frame(width: 330, height: 330)
                .allowsHitTesting(false)
        }
        .overlay {
            if points.isEmpty && venues.isEmpty {
                EmptyMapState()
                    .padding(.horizontal, 24)
                    .allowsHitTesting(false)
            }
        }
    }
}

protocol VenueSearching {
    func search(
        definition: VenueSearchDefinition,
        region: MKCoordinateRegion
    ) async throws -> [MeetingPlace]
}

struct AppleMapsVenueSearcher: VenueSearching {
    func search(
        definition: VenueSearchDefinition,
        region: MKCoordinateRegion
    ) async throws -> [MeetingPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = definition.query
        request.region = region
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: definition.categories)
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.compactMap(MeetingPlace.from)
    }
}

enum VenueResultProcessor {
    static func process(
        _ places: [MeetingPlace],
        around coordinate: CLLocationCoordinate2D,
        radiusM: CLLocationDistance = VenueDiscoveryConfig.searchRadiusM,
        limit: Int = VenueDiscoveryConfig.resultLimit
    ) -> [MeetingPlace] {
        let unique = Dictionary(
            places.map { ($0.deduplicationKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return Array(
            unique.values
                .filter {
                    origin.distance(
                        from: CLLocation(
                            latitude: $0.coordinate.latitude,
                            longitude: $0.coordinate.longitude
                        )
                    ) <= radiusM
                }
                .sorted {
                    origin.distance(
                        from: CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                    ) < origin.distance(
                        from: CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude)
                    )
                }
                .prefix(limit)
        )
    }
}

@MainActor
final class NearbyVenueStore: ObservableObject {
    @Published private(set) var venues: [MeetingPlace] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let searcher: any VenueSearching
    private var lastCoordinateKey: String?
    private var requestID = UUID()

    init(searcher: any VenueSearching = AppleMapsVenueSearcher()) {
        self.searcher = searcher
    }

    func load(around coordinate: CLLocationCoordinate2D) async {
        let coordinateKey = String(format: "%.4f:%.4f", coordinate.latitude, coordinate.longitude)
        guard coordinateKey != lastCoordinateKey else { return }

        lastCoordinateKey = coordinateKey
        let currentRequestID = UUID()
        requestID = currentRequestID
        isLoading = true
        errorMessage = nil

        var loadedVenues: [MeetingPlace] = []
        var successfulSearches = 0
        var searchErrors: [Error] = []
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: VenueDiscoveryConfig.searchRadiusM * 2,
            longitudinalMeters: VenueDiscoveryConfig.searchRadiusM * 2
        )
        for definition in VenueDiscoveryConfig.searches {
            do {
                loadedVenues.append(contentsOf: try await searcher.search(definition: definition, region: region))
                successfulSearches += 1
            } catch {
                searchErrors.append(error)
            }
        }

        guard currentRequestID == requestID else { return }
        if successfulSearches == 0 {
            errorMessage = VenueSearchErrorPresenter.message(for: searchErrors)
        } else {
            venues = VenueResultProcessor.process(loadedVenues, around: coordinate)
        }
        isLoading = false
    }

    func reload(around coordinate: CLLocationCoordinate2D) async {
        lastCoordinateKey = nil
        await load(around: coordinate)
    }

    func clear() {
        requestID = UUID()
        venues = []
        lastCoordinateKey = nil
        isLoading = false
        errorMessage = nil
    }
}

enum VenueSearchErrorPresenter {
    static func message(for errors: [Error]) -> String? {
        guard !errors.isEmpty else { return nil }
        if errors.allSatisfy({ $0 is CancellationError }) {
            return nil
        }
        if errors.contains(where: { $0 is URLError }) {
            return "Could not reach Apple Maps. Check your internet connection or tap refresh."
        }
        return "Apple Maps could not load meeting places right now. Move the map or tap refresh."
    }
}

private struct LAVenueMarker: View {
    let category: MeetingPlaceCategory
    let isSelected: Bool

    var body: some View {
        Image(systemName: category.symbolName)
            .font(.caption.weight(.black))
            .foregroundStyle(.white)
            .frame(width: isSelected ? 40 : 34, height: isSelected ? 40 : 34)
            .background(isSelected ? NOWColor.laOrange : NOWColor.laCoral)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: isSelected ? 3 : 2))
            .shadow(color: NOWColor.ink.opacity(0.22), radius: 5, y: 3)
    }
}

private struct SelectedVenueCard: View {
    let venue: MeetingPlace
    let clear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: venue.category.symbolName)
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(NOWColor.laCoral)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Meeting place selected")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(NOWColor.laCoral)
                Text(venue.name)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(NOWColor.laBrown)
                    .lineLimit(1)
                Text(venue.category.displayName)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(NOWColor.laCoral)
                Text(venue.address)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(NOWColor.inkSoft)
                    .lineLimit(2)
            }

            Spacer()

            Button("Clear", action: clear)
                .font(.caption.weight(.heavy))
                .foregroundStyle(NOWColor.laCoral)
        }
        .padding(12)
        .background(NOWColor.surface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private extension MKCoordinateRegion {
    static func fitting(points: [MapPoint], userCoordinate: CLLocationCoordinate2D?) -> MKCoordinateRegion? {
        let coordinates = ([userCoordinate].compactMap { $0 }) + points.map(\.approximateCoordinate)

        guard !coordinates.isEmpty else {
            return nil
        }

        guard coordinates.count > 1 else {
            return MKCoordinateRegion(
                center: coordinates[0],
                span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
            )
        }

        let minLat = coordinates.map(\.latitude).min() ?? coordinates[0].latitude
        let maxLat = coordinates.map(\.latitude).max() ?? coordinates[0].latitude
        let minLng = coordinates.map(\.longitude).min() ?? coordinates[0].longitude
        let maxLng = coordinates.map(\.longitude).max() ?? coordinates[0].longitude

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let latDelta = max(0.01, (maxLat - minLat) * 2.1)
        let lngDelta = max(0.01, (maxLng - minLng) * 2.1)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
        )
    }
}

private struct LAUserLocationMarker: View {
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(NOWColor.surface)
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(NOWColor.laBlue, lineWidth: 5))
            Text("You")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(NOWColor.surface)
                .fixedSize()
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(NOWColor.laBlue)
                .clipShape(Capsule())
        }
        .shadow(color: NOWColor.laBlue.opacity(0.35), radius: 14, x: 0, y: 6)
        .accessibilityLabel("Your location")
    }
}

private struct EmptyMapState: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("No one live nearby yet")
                .font(.headline.weight(.black))
                .foregroundStyle(NOWColor.ink)
            Text("You're online. New live points will appear here.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(NOWColor.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(NOWColor.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NOWColor.line.opacity(0.8), lineWidth: 1)
        )
    }
}

private struct LAMapPersonMarker: View {
    let point: MapPoint
    var isCurrentMatch = false
    var isLocked = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(markerFill)
                    .frame(width: 46, height: 46)
                    .overlay(Circle().stroke(markerStroke, lineWidth: 3))
                    .shadow(color: NOWColor.ink.opacity(0.18), radius: 10, x: 0, y: 6)

                if point.profile.mainPhotoURL != nil {
                    ProfilePhoto(profile: point.profile)
                        .frame(width: 46, height: 46)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(markerStroke, lineWidth: 3))
                        .shadow(color: NOWColor.ink.opacity(0.18), radius: 10, x: 0, y: 6)
                }

                if let markerSymbol {
                    Image(systemName: markerSymbol)
                        .font(.system(size: point.profile.mainPhotoURL == nil ? 20 : 12, weight: .black))
                        .foregroundStyle(markerSymbolColor)
                        .padding(point.profile.mainPhotoURL == nil ? 0 : 5)
                        .background(point.profile.mainPhotoURL == nil ? Color.clear : NOWColor.surface.opacity(0.9))
                        .clipShape(Circle())
                        .offset(x: point.profile.mainPhotoURL == nil ? 0 : 18, y: point.profile.mainPhotoURL == nil ? 0 : 18)
                }
            }

            Text("\(point.profile.name) · \(point.profile.planSummary)")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(labelForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(labelBackground)
                .clipShape(Capsule())
                .shadow(color: NOWColor.ink.opacity(0.12), radius: 8, x: 0, y: 4)
        }
        .opacity(isLocked && !isCurrentMatch ? 0.48 : 1)
    }

    private var markerFill: Color {
        if isCurrentMatch {
            return NOWColor.laOrange
        }

        switch point.state {
        case .unseen:
            return NOWColor.laGreen
        case .viewed, .interested, .triedBefore:
            return NOWColor.laBrownSoft.opacity(0.22)
        case .blocked:
            return NOWColor.laBrownSoft.opacity(0.45)
        }
    }

    private var markerStroke: Color {
        if isCurrentMatch {
            return NOWColor.surface
        }

        switch point.state {
        case .viewed, .interested, .triedBefore:
            return NOWColor.laBrownSoft.opacity(0.58)
        default:
            return markerFill
        }
    }

    private var labelBackground: Color {
        if isCurrentMatch {
            return NOWColor.surface
        }

        switch point.state {
        case .unseen:
            return NOWColor.laGreen
        case .viewed, .interested, .triedBefore:
            return NOWColor.surface.opacity(0.72)
        case .blocked:
            return NOWColor.laBrownSoft
        }
    }

    private var labelForeground: Color {
        point.state == .blocked ? NOWColor.surface : NOWColor.ink
    }

    private var markerSymbol: String? {
        if isCurrentMatch {
            return "message.fill"
        }

        if point.alreadyMatched {
            return "heart.fill"
        }

        switch point.state {
        case .interested:
            return "heart.fill"
        case .triedBefore:
            return "xmark"
        default:
            return nil
        }
    }

    private var markerSymbolColor: Color {
        if isCurrentMatch {
            return NOWColor.ink
        }

        return point.alreadyMatched || point.state == .interested ? NOWColor.laCoral : NOWColor.laBrown
    }
}
