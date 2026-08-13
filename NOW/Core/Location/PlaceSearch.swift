import MapKit
import SwiftUI

struct MeetingPlace: Equatable, Identifiable {
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D

    var id: String {
        "\(coordinate.latitude),\(coordinate.longitude),\(name)"
    }

    static func == (lhs: MeetingPlace, rhs: MeetingPlace) -> Bool {
        lhs.name == rhs.name
            && lhs.address == rhs.address
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

private struct PlaceSearchSuggestion: Identifiable {
    let id = UUID()
    let completion: MKLocalSearchCompletion

    var title: String { completion.title }
    var subtitle: String { completion.subtitle }
}

private final class PlaceSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
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
    private let searchRegion: MKCoordinateRegion?
    private var hasLoadedNearbyCafes = false

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

    func loadNearbyCafes() async {
        guard !hasLoadedNearbyCafes else { return }
        hasLoadedNearbyCafes = true
        await searchMap(for: "Cafe")
    }

    func searchMapForCurrentQuery() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        await searchMap(for: trimmedQuery.isEmpty ? "Cafe" : trimmedQuery)
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

            guard let place = meetingPlace(from: item) else {
                errorMessage = "This place does not have a confirmed name and address."
                return nil
            }

            return place
        } catch {
            errorMessage = "Could not confirm this place. Try another result."
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
        isSearchingMap = true
        errorMessage = nil
        defer { isSearchingMap = false }

        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = .pointOfInterest
            if let searchRegion {
                request.region = searchRegion
            }

            let response = try await MKLocalSearch(request: request).start()
            mapPlaces = Array(response.mapItems.compactMap(meetingPlace(from:)).prefix(20))
            if mapPlaces.isEmpty {
                errorMessage = "No matching places found in this area."
            }
        } catch {
            errorMessage = "Could not load places on the map. Try again."
        }
    }

    private func meetingPlace(from item: MKMapItem) -> MeetingPlace? {
        let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = item.placemark.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty, let address, !address.isEmpty else { return nil }
        return MeetingPlace(name: name, address: address, coordinate: item.placemark.coordinate)
    }
}

struct PlaceSearchField: View {
    @Binding private var selectedPlace: MeetingPlace?
    @StateObject private var search: PlaceSearchService
    @State private var mapPosition: MapCameraPosition

    init(selectedPlace: Binding<MeetingPlace?>, regionCenter: CLLocationCoordinate2D?) {
        _selectedPlace = selectedPlace
        _search = StateObject(wrappedValue: PlaceSearchService(regionCenter: regionCenter))
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
                    Text(search.query.isEmpty ? "Nearby cafes" : "Places on the map")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(NOWColor.laBrown)
                    Spacer()
                    if search.isSearchingMap {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Map(position: $mapPosition, interactionModes: [.pan, .zoom]) {
                    ForEach(search.mapPlaces) { place in
                        Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                            Button {
                                choose(place)
                            } label: {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(NOWColor.laCoral)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Select \(place.name), \(place.address)")
                        }
                    }
                }
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(NOWColor.laBrown.opacity(0.18), lineWidth: 1)
                )

                if search.isResolving {
                    ProgressView("Confirming place…")
                        .font(.caption.weight(.semibold))
                }

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
            await search.loadNearbyCafes()
        }
    }

    private func choose(_ place: MeetingPlace) {
        selectedPlace = place
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
