import MapKit
import SwiftUI

struct MeetingPlace: Equatable {
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D

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
    @Published private(set) var isResolving = false
    @Published private(set) var errorMessage: String?

    private let completer = MKLocalSearchCompleter()

    init(regionCenter: CLLocationCoordinate2D?) {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        if let regionCenter {
            completer.region = MKCoordinateRegion(
                center: regionCenter,
                latitudinalMeters: 40_000,
                longitudinalMeters: 40_000
            )
        }
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

            let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let address = item.placemark.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let name, !name.isEmpty, let address, !address.isEmpty else {
                errorMessage = "This place does not have a confirmed name and address."
                return nil
            }

            return MeetingPlace(name: name, address: address, coordinate: item.placemark.coordinate)
        } catch {
            errorMessage = "Could not confirm this place. Try another result."
            return nil
        }
    }

    func select(_ place: MeetingPlace) {
        query = place.name
        suggestions = []
        errorMessage = nil
    }

    func clear() {
        query = ""
        suggestions = []
        errorMessage = nil
    }
}

struct PlaceSearchField: View {
    @Binding private var selectedPlace: MeetingPlace?
    @StateObject private var search: PlaceSearchService

    init(selectedPlace: Binding<MeetingPlace?>, regionCenter: CLLocationCoordinate2D?) {
        _selectedPlace = selectedPlace
        _search = StateObject(wrappedValue: PlaceSearchService(regionCenter: regionCenter))
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

                if search.isResolving {
                    ProgressView("Confirming place…")
                        .font(.caption.weight(.semibold))
                }

                ForEach(search.suggestions) { suggestion in
                    Button {
                        Task {
                            if let place = await search.resolve(suggestion) {
                                selectedPlace = place
                                search.select(place)
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
    }
}
