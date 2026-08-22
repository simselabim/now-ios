import MapKit
import SwiftUI

enum MeetingPlaceCategory: String, Codable, CaseIterable, Sendable {
    case cafe
    case restaurant
    case bar
    case hotel
    case beach
    case park
    case shopping
    case culture
    case activity
    case transit
    case publicSpace = "public_space"
    case other

    var displayName: String {
        switch self {
        case .cafe: "Cafe"
        case .restaurant: "Restaurant"
        case .bar: "Bar"
        case .hotel: "Hotel"
        case .beach: "Beach"
        case .park: "Park"
        case .shopping: "Shopping"
        case .culture: "Culture"
        case .activity: "Activity"
        case .transit: "Transit"
        case .publicSpace: "Public place"
        case .other: "Place"
        }
    }

    var symbolName: String {
        switch self {
        case .cafe: "cup.and.saucer.fill"
        case .restaurant: "fork.knife"
        case .bar: "wineglass.fill"
        case .hotel: "bed.double.fill"
        case .beach: "beach.umbrella.fill"
        case .park: "leaf.fill"
        case .shopping: "bag.fill"
        case .culture: "building.columns.fill"
        case .activity: "figure.walk"
        case .transit: "tram.fill"
        case .publicSpace: "mappin.and.ellipse"
        case .other: "mappin.circle.fill"
        }
    }
}

struct VenueSearchDefinition {
    let query: String
    let categories: [MKPointOfInterestCategory]
}

enum VenueDiscoveryConfig {
    static let initialViewportSpanM: CLLocationDistance = 5_000
    static let searchRadiusM: CLLocationDistance = 5_000
    static let searchDebounceMilliseconds = 300
    static let resultLimit = 30

    static let searches: [VenueSearchDefinition] = [
        VenueSearchDefinition(query: "Cafe", categories: [.cafe, .bakery]),
        VenueSearchDefinition(query: "Restaurant", categories: [.restaurant, .foodMarket]),
        VenueSearchDefinition(query: "Bar", categories: [.nightlife, .brewery, .winery]),
        VenueSearchDefinition(query: "Hotel", categories: [.hotel, .campground]),
        VenueSearchDefinition(query: "Beach", categories: [.beach, .marina]),
        VenueSearchDefinition(query: "Park", categories: [.park, .nationalPark]),
        VenueSearchDefinition(query: "Shopping mall", categories: [.store, .foodMarket]),
        VenueSearchDefinition(
            query: "Museum gallery attraction",
            categories: [.museum, .theater, .movieTheater, .aquarium, .zoo, .amusementPark]
        ),
        VenueSearchDefinition(query: "Activity", categories: [.fitnessCenter, .stadium]),
        VenueSearchDefinition(
            query: "Public place",
            categories: [.library, .university, .airport, .publicTransport]
        )
    ]

    static var supportedPointOfInterestCategories: [MKPointOfInterestCategory] {
        searches.flatMap(\.categories)
    }

    static var radiusLabel: String {
        "\(Int(searchRadiusM / 1_000)) km"
    }

    static func category(for pointOfInterestCategory: MKPointOfInterestCategory?) -> MeetingPlaceCategory {
        guard let pointOfInterestCategory else { return .other }

        if [.cafe, .bakery].contains(pointOfInterestCategory) { return .cafe }
        if [.restaurant, .foodMarket].contains(pointOfInterestCategory) { return .restaurant }
        if [.nightlife, .brewery, .winery].contains(pointOfInterestCategory) { return .bar }
        if [.hotel, .campground].contains(pointOfInterestCategory) { return .hotel }
        if [.beach, .marina].contains(pointOfInterestCategory) { return .beach }
        if [.park, .nationalPark].contains(pointOfInterestCategory) { return .park }
        if [.store].contains(pointOfInterestCategory) { return .shopping }
        if [
            .museum, .theater, .movieTheater, .aquarium, .zoo, .amusementPark
        ].contains(pointOfInterestCategory) {
            return .culture
        }
        if [.fitnessCenter, .stadium].contains(pointOfInterestCategory) { return .activity }
        if [.airport, .publicTransport].contains(pointOfInterestCategory) { return .transit }
        if [.library, .university].contains(pointOfInterestCategory) { return .publicSpace }
        return .other
    }

    static func supports(_ pointOfInterestCategory: MKPointOfInterestCategory?) -> Bool {
        guard let pointOfInterestCategory else { return false }
        return supportedPointOfInterestCategories.contains(pointOfInterestCategory)
    }
}

struct MeetingPlace: Equatable, Identifiable {
    let externalID: String
    let name: String
    let category: MeetingPlaceCategory
    let address: String
    let coordinate: CLLocationCoordinate2D

    var id: String {
        externalID
    }

    var deduplicationKey: String {
        externalID.lowercased()
    }

    static func == (lhs: MeetingPlace, rhs: MeetingPlace) -> Bool {
        lhs.externalID == rhs.externalID
            && lhs.name == rhs.name
            && lhs.category == rhs.category
            && lhs.address == rhs.address
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }

    static func from(_ item: MKMapItem) -> MeetingPlace? {
        let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = item.placemark.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty, let address, !address.isEmpty else { return nil }

        let coordinate = item.placemark.coordinate
        let externalID: String
        if #available(iOS 18.0, *), let appleMapsID = item.identifier?.rawValue {
            externalID = appleMapsID
        } else {
            externalID = legacyExternalID(name: name, address: address, coordinate: coordinate)
        }

        return MeetingPlace(
            externalID: externalID,
            name: name,
            category: VenueDiscoveryConfig.category(for: item.pointOfInterestCategory),
            address: address,
            coordinate: coordinate
        )
    }

    static func legacyExternalID(
        name: String,
        address: String,
        coordinate: CLLocationCoordinate2D
    ) -> String {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        _ = address
        return String(
            format: "legacy:%.6f:%.6f:%@",
            coordinate.latitude,
            coordinate.longitude,
            normalizedName
        )
    }
}

private struct PlaceSearchSuggestion: Identifiable {
    let id = UUID()
    let completion: MKLocalSearchCompletion

    var title: String { completion.title }
    var subtitle: String { completion.subtitle }
}

@MainActor
private final class PlaceSearchService: NSObject, ObservableObject, @MainActor MKLocalSearchCompleterDelegate {
    @Published var query = "" {
        didSet {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedQuery.isEmpty {
                suggestions = []
                completer.queryFragment = ""
            } else {
                completer.queryFragment = trimmedQuery
            }
        }
    }
    @Published private(set) var suggestions: [PlaceSearchSuggestion] = []
    @Published private(set) var mapPlaces: [MeetingPlace] = []
    @Published private(set) var isSearchingMap = false
    @Published private(set) var isResolving = false
    @Published private(set) var errorMessage: String?

    private let completer = MKLocalSearchCompleter()
    private var searchRegion: MKCoordinateRegion?
    private var hasLoadedNearbyPlaces = false
    private var mapSearchID = UUID()

    init(regionCenter: CLLocationCoordinate2D?) {
        searchRegion = regionCenter.map {
            MKCoordinateRegion(
                center: $0,
                latitudinalMeters: 12_000,
                longitudinalMeters: 12_000
            )
        }
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        if let searchRegion {
            completer.region = searchRegion
        }
    }

    func loadNearbyPlaces() async {
        guard !hasLoadedNearbyPlaces else { return }
        hasLoadedNearbyPlaces = true
        await searchSupportedPlaces()
    }

    func searchMapForCurrentQuery() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            await searchSupportedPlaces()
        } else {
            await searchMap(for: trimmedQuery)
        }
    }

    func searchMap(in region: MKCoordinateRegion) async {
        searchRegion = region
        completer.region = region
        await searchMapForCurrentQuery()
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            suggestions = []
            return
        }
        suggestions = Array(completer.results.prefix(6)).map(PlaceSearchSuggestion.init)
        errorMessage = nil
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
        errorMessage = "Could not search places. Try again."
    }

    func resolve(_ suggestion: PlaceSearchSuggestion) async -> MeetingPlace? {
        isResolving = true
        errorMessage = nil
        defer { isResolving = false }

        do {
            let request = MKLocalSearch.Request(completion: suggestion.completion)
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                errorMessage = "This place is no longer available."
                return nil
            }

            guard let place = MeetingPlace.from(item) else {
                errorMessage = "This place does not have a confirmed name and address."
                return nil
            }

            return place
        } catch {
            errorMessage = "Could not confirm this place. Try another result."
            return nil
        }
    }

    func resolve(_ feature: MapFeature) async -> MeetingPlace? {
        guard feature.kind == .pointOfInterest,
              VenueDiscoveryConfig.supports(feature.pointOfInterestCategory) else {
            errorMessage = "Choose a public place suitable for meeting."
            return nil
        }

        isResolving = true
        errorMessage = nil
        defer { isResolving = false }

        do {
            let item = try await MKMapItemRequest(feature: feature).mapItem
            guard VenueDiscoveryConfig.supports(item.pointOfInterestCategory),
                  let place = MeetingPlace.from(item) else {
                errorMessage = "This place does not have enough public place details."
                return nil
            }
            return place
        } catch {
            errorMessage = "Could not confirm this place. Try another marker."
            return nil
        }
    }

    func select(_ place: MeetingPlace) {
        query = place.name
        suggestions = []
        if !mapPlaces.contains(place) {
            mapPlaces.insert(place, at: 0)
        }
        errorMessage = nil
    }

    func clear() {
        query = ""
        suggestions = []
        errorMessage = nil
    }

    private func searchMap(for query: String) async {
        let requestID = UUID()
        mapSearchID = requestID
        isSearchingMap = true
        errorMessage = nil
        defer {
            if requestID == mapSearchID {
                isSearchingMap = false
            }
        }

        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = .pointOfInterest
            if let searchRegion {
                request.region = searchRegion
            }

            let response = try await MKLocalSearch(request: request).start()
            guard requestID == mapSearchID else { return }
            mapPlaces = Array(response.mapItems.compactMap(MeetingPlace.from).prefix(VenueDiscoveryConfig.resultLimit))
            if mapPlaces.isEmpty {
                errorMessage = "No matching places found in this area."
            }
        } catch {
            guard requestID == mapSearchID else { return }
            errorMessage = "Could not load places on the map. Try again."
        }
    }

    private func searchSupportedPlaces() async {
        let requestID = UUID()
        mapSearchID = requestID
        isSearchingMap = true
        errorMessage = nil
        defer {
            if requestID == mapSearchID {
                isSearchingMap = false
            }
        }

        var places: [MeetingPlace] = []
        var successfulSearches = 0
        for definition in VenueDiscoveryConfig.searches {
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = definition.query
                request.resultTypes = .pointOfInterest
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: definition.categories)
                if let searchRegion {
                    request.region = searchRegion
                }
                let response = try await MKLocalSearch(request: request).start()
                successfulSearches += 1
                places.append(contentsOf: response.mapItems.compactMap(MeetingPlace.from))
            } catch {
                continue
            }
        }

        guard requestID == mapSearchID else { return }
        let unique = Dictionary(places.map { ($0.deduplicationKey, $0) }, uniquingKeysWith: { first, _ in first })
        mapPlaces = Array(unique.values.prefix(VenueDiscoveryConfig.resultLimit))
        if successfulSearches == 0 {
            errorMessage = "Could not load places on the map. Try again."
        } else if mapPlaces.isEmpty {
            errorMessage = "No meeting places found in this area."
        }
    }
}

struct PlaceSearchField: View {
    @Binding private var selectedPlace: MeetingPlace?
    @StateObject private var search: PlaceSearchService
    @State private var mapPosition: MapCameraPosition
    @State private var selectedMapFeature: MapFeature?
    private let mapHeight: CGFloat
    private let mapHorizontalOverflow: CGFloat

    init(
        selectedPlace: Binding<MeetingPlace?>,
        regionCenter: CLLocationCoordinate2D?,
        mapHeight: CGFloat = 210,
        mapHorizontalOverflow: CGFloat = 0
    ) {
        _selectedPlace = selectedPlace
        _search = StateObject(wrappedValue: PlaceSearchService(regionCenter: regionCenter))
        self.mapHeight = mapHeight
        self.mapHorizontalOverflow = mapHorizontalOverflow
        _mapPosition = State(
            initialValue: regionCenter.map {
                .region(
                    MKCoordinateRegion(
                        center: $0,
                        latitudinalMeters: 5_000,
                        longitudinalMeters: 5_000
                    )
                )
            } ?? .automatic
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selectedPlace {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(NOWColor.laCoral)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedPlace.name)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(NOWColor.laBrown)
                        Text(selectedPlace.category.displayName)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(NOWColor.laCoral)
                        Text(selectedPlace.address)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(NOWColor.inkSoft)
                    }

                    Spacer()

                    Button("Change") {
                        self.selectedPlace = nil
                        search.clear()
                    }
                    .font(.caption.weight(.heavy))
                }
                .padding(11)
                .background(NOWColor.paper)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("selected-meeting-place")
            } else {
                TextField(
                    "Search a real place or address",
                    text: Binding(
                        get: { search.query },
                        set: { search.query = $0 }
                    )
                )
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(11)
                .background(NOWColor.paper)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .submitLabel(.search)
                .onSubmit {
                    Task { await search.searchMapForCurrentQuery() }
                }

                HStack {
                    Text(search.query.isEmpty ? "Nearby meeting places" : "Places on the map")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(NOWColor.laBrown)
                    Spacer()
                    if search.isSearchingMap {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }

            Map(
                position: $mapPosition,
                interactionModes: [.pan, .zoom],
                selection: $selectedMapFeature
            ) {
                ForEach(search.mapPlaces) { place in
                    Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                        Button {
                            choose(place)
                        } label: {
                            let isSelected = selectedPlace?.id == place.id
                            Image(systemName: place.category.symbolName)
                                .font(.caption.weight(.black))
                                .foregroundStyle(.white)
                                .frame(width: isSelected ? 40 : 32, height: isSelected ? 40 : 32)
                                .background(isSelected ? NOWColor.laOrange : NOWColor.laCoral)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.white, lineWidth: isSelected ? 3 : 2))
                                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Select \(place.name), \(place.address)")
                        .accessibilityIdentifier("meeting-place-marker-\(place.id)")
                    }
                }
            }
            .frame(height: mapHeight)
            .padding(.horizontal, -mapHorizontalOverflow)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(NOWColor.laBrown.opacity(0.18), lineWidth: 1)
            )
            .accessibilityIdentifier("meeting-place-map")
            .onChange(of: selectedMapFeature) { _, feature in
                guard let feature else { return }
                Task {
                    if let place = await search.resolve(feature) {
                        choose(place)
                    } else {
                        selectedMapFeature = nil
                    }
                }
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                guard selectedPlace == nil else { return }
                Task { await search.searchMap(in: context.region) }
            }

            if search.isResolving {
                ProgressView("Confirming place…")
                    .font(.caption.weight(.semibold))
            }

            if selectedPlace == nil {
                ForEach(search.suggestions) { suggestion in
                    Button {
                        Task {
                            if let place = await search.resolve(suggestion) {
                                choose(place)
                            }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(NOWColor.laCoral)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(NOWColor.laBrown)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(NOWColor.inkSoft)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let errorMessage = search.errorMessage {
                Text(errorMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NOWColor.laCoral)
            }
        }
        .task {
            await search.loadNearbyPlaces()
        }
    }

    private func choose(_ place: MeetingPlace) {
        selectedPlace = place
        selectedMapFeature = nil
        search.select(place)
        mapPosition = .region(
            MKCoordinateRegion(
                center: place.coordinate,
                latitudinalMeters: 1_200,
                longitudinalMeters: 1_200
            )
        )
    }
}
