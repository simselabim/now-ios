import CoreLocation
import Foundation
import MapKit
import XCTest
@testable import NOW

@MainActor
final class DiscoveryMapNavigationTests: XCTestCase {
    func testClosingProfilePreservesMapPointAndViewport() {
        let state = AppState()
        let point = makePoint(state: .viewed)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -8.6478, longitude: 115.1385),
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.03)
        )

        state.mapPoints = [point]
        state.selectedPoint = point
        state.rememberDiscoveryMapRegion(region)

        state.closeProfilePreview()

        XCTAssertNil(state.selectedPoint)
        XCTAssertEqual(state.mapPoints, [point])
        XCTAssertEqual(state.discoveryMapRegion?.center.latitude, region.center.latitude)
        XCTAssertEqual(state.discoveryMapRegion?.center.longitude, region.center.longitude)
        XCTAssertEqual(state.discoveryMapRegion?.span.latitudeDelta, region.span.latitudeDelta)
        XCTAssertEqual(state.discoveryMapRegion?.span.longitudeDelta, region.span.longitudeDelta)
    }

    func testProfileBackButtonRemainsWiredOutsideTheScrollableContent() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryURL.appendingPathComponent(
                "NOW/Features/ProfilePreview/ProfilePreviewScreen.swift"
            ),
            encoding: .utf8
        )

        let headerIndex = try XCTUnwrap(source.range(of: "profileHeader(point)")?.lowerBound)
        let scrollIndex = try XCTUnwrap(source.range(of: "ScrollView {")?.lowerBound)
        XCTAssertLessThan(headerIndex, scrollIndex)
        XCTAssertTrue(source.contains("appState.closeProfilePreview()"))
        XCTAssertTrue(source.contains("profile-preview-back"))
    }

    func testMapPointEqualityDetectsViewedStateChange() {
        XCTAssertNotEqual(makePoint(state: .unseen), makePoint(state: .viewed))
    }

    func testSuccessfulSayHiStaysInterestedAcrossProfileAndMapRefresh() {
        var mapState = MapPointStateReconciliation.openedState(.unseen)
        XCTAssertEqual(mapState, .viewed)

        mapState = .interested
        let reopenedProfileState = MapPointStateReconciliation.openedState(.interested)
        XCTAssertEqual(reopenedProfileState, .interested)

        mapState = MapPointStateReconciliation.refreshedState(
            serverState: .viewed,
            currentState: mapState
        )
        XCTAssertEqual(mapState, .interested)
    }

    func testFailedSayHiDoesNotCreateInterestedMapState() {
        XCTAssertEqual(
            MapPointStateReconciliation.refreshedState(
                serverState: .viewed,
                currentState: .viewed
            ),
            .viewed
        )
    }

    func testGoOfflineImmediatelyLeavesMapAndIgnoresLateDiscoveryResponse() async throws {
        let tokenStore = InMemoryAuthTokenStore()
        await tokenStore.setAccessToken("test-token")
        let discoverStarted = DispatchSemaphore(value: 0)
        let releaseDiscover = DispatchSemaphore(value: 0)

        ReopenMatchURLProtocol.reset()
        ReopenMatchURLProtocol.handler = { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/matches/active/detail"):
                return Self.jsonResponse(for: request, body: #"{"match_item":null}"#)
            case ("GET", "/discover/map"):
                discoverStarted.signal()
                _ = releaseDiscover.wait(timeout: .now() + 2)
                return Self.jsonResponse(
                    for: request,
                    body: #"{"radius_m":50000,"discovery_locked":false,"points":[]}"#
                )
            case ("DELETE", "/online"):
                return Self.jsonResponse(
                    for: request,
                    body: #"{"status":"offline","closed_sessions":1}"#
                )
            default:
                throw URLError(.badURL)
            }
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReopenMatchURLProtocol.self]
        let client = NOWAPIClient(
            environment: APIEnvironment(baseURL: URL(string: "https://now.test")!),
            session: URLSession(configuration: configuration),
            tokenStore: tokenStore
        )
        let state = AppState(apiClient: client)
        state.isOnline = true
        state.mapPoints = [makePoint(state: .unseen)]
        state.rememberDiscoveryMapRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -8.6478, longitude: 115.1385),
                span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.03)
            )
        )

        state.refreshActiveMatch()
        let didStartDiscovery = await Task.detached {
            discoverStarted.wait(timeout: .now() + 2) == .success
        }.value
        XCTAssertTrue(didStartDiscovery)

        state.goOffline()

        XCTAssertFalse(state.isOnline)
        XCTAssertTrue(state.mapPoints.isEmpty)
        XCTAssertNil(state.discoveryMapRegion)

        releaseDiscover.signal()
        for _ in 0..<100 where state.isLoading {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(ReopenMatchURLProtocol.requestCount(path: "/online"), 1)
        XCTAssertFalse(state.isOnline)
        XCTAssertTrue(state.mapPoints.isEmpty)
        XCTAssertNil(state.discoveryRadiusM)
    }

    func testEmptyDiscoveryIsNormalStateWithoutUserFacingError() async throws {
        let tokenStore = InMemoryAuthTokenStore()
        await tokenStore.setAccessToken("test-token")
        ReopenMatchURLProtocol.reset()
        ReopenMatchURLProtocol.handler = { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/matches/active/detail"):
                return Self.jsonResponse(for: request, body: #"{"match_item":null}"#)
            case ("GET", "/discover/map"):
                return Self.jsonResponse(
                    for: request,
                    body: #"{"radius_m":50000,"discovery_locked":false,"points":[]}"#
                )
            default:
                throw URLError(.badURL)
            }
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReopenMatchURLProtocol.self]
        let client = NOWAPIClient(
            environment: APIEnvironment(baseURL: URL(string: "https://now.test")!),
            session: URLSession(configuration: configuration),
            tokenStore: tokenStore
        )
        let state = AppState(apiClient: client)
        state.isOnline = true

        state.refreshActiveMatch()
        for _ in 0..<100 where state.isLoading || ReopenMatchURLProtocol.requestCount(path: "/discover/map") == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertTrue(state.isOnline)
        XCTAssertTrue(state.mapPoints.isEmpty)
        XCTAssertEqual(state.discoveryRadiusM, 50_000)
        XCTAssertNil(state.errorMessage)
    }

    func testCancelledPointStartsFromProfileWithoutReopeningPreviousMatch() async throws {
        let matchID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let otherUserID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let pointID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let tokenStore = InMemoryAuthTokenStore()
        await tokenStore.setAccessToken("test-token")
        ReopenMatchURLProtocol.reset()
        ReopenMatchURLProtocol.handler = { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/discover/points/\(pointID.uuidString)"):
                return Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "point": {
                        "point_id": "\(pointID.uuidString)",
                        "profile_id": "11111111-1111-1111-1111-111111111111",
                        "user_id": "\(otherUserID.uuidString)",
                        "display_name": "Nearby",
                        "main_photo_storage_key": null,
                        "plans": ["coffee"],
                        "intents": ["friendly"],
                        "times_today": ["now"],
                        "lat": -8.648,
                        "lng": 115.139,
                        "distance_m": 800,
                        "state": "cancelled_match_before",
                        "already_matched": true,
                        "last_match_id": "\(matchID.uuidString)",
                        "last_seen_at": "2026-08-22T08:00:00Z"
                      },
                      "profile": {
                        "id": "11111111-1111-1111-1111-111111111111",
                        "user_id": "\(otherUserID.uuidString)",
                        "display_name": "Nearby",
                        "birth_date": "1996-01-01",
                        "gender": "woman",
                        "bio": "Hello",
                        "interests": [],
                        "is_publishable": true,
                        "published_at": "2026-08-22T07:00:00Z",
                        "photos": [],
                        "intro_loop": null,
                        "created_at": "2026-08-22T07:00:00Z",
                        "updated_at": "2026-08-22T07:00:00Z"
                      }
                    }
                    """
                )
            default:
                throw URLError(.badURL)
            }
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReopenMatchURLProtocol.self]
        let client = NOWAPIClient(
            environment: APIEnvironment(baseURL: URL(string: "https://now.test")!),
            session: URLSession(configuration: configuration),
            tokenStore: tokenStore
        )
        let state = AppState(apiClient: client)
        let point = makePoint(state: .triedBefore, alreadyMatched: true, lastMatchID: matchID)

        state.viewPoint(point)

        for _ in 0..<100 where state.selectedPoint == nil {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertNil(state.activeMatch)
        XCTAssertEqual(state.selectedPoint?.profile.id, point.profile.id)
        XCTAssertEqual(ReopenMatchURLProtocol.requestCount(path: "/matches/\(matchID.uuidString)/reopen"), 0)
        XCTAssertEqual(ReopenMatchURLProtocol.requestCount(path: "/discover/points/\(pointID.uuidString)"), 1)
    }

    func testCloseKindlySendsOnlyOneCancellationForRapidTaps() async throws {
        let matchID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        let otherUserID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
        let tokenStore = InMemoryAuthTokenStore()
        await tokenStore.setAccessToken("test-token")
        ReopenMatchURLProtocol.reset()
        ReopenMatchURLProtocol.handler = { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/matches/\(matchID.uuidString)/cancel"):
                return Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "id": "\(matchID.uuidString)",
                      "user_a_id": "99999999-9999-9999-9999-999999999999",
                      "user_b_id": "\(otherUserID.uuidString)",
                      "other_user_id": "\(otherUserID.uuidString)",
                      "match_date": "2026-08-22",
                      "status": "cancelled",
                      "created_at": "2026-08-22T04:00:00Z",
                      "closed_at": "2026-08-22T05:00:00Z",
                      "extended_until": null,
                      "extension_accepted_at": null
                    }
                    """
                )
            case ("GET", "/discover/map"):
                return Self.jsonResponse(
                    for: request,
                    body: #"{"radius_m":50000,"discovery_locked":false,"points":[]}"#
                )
            default:
                throw URLError(.badURL)
            }
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReopenMatchURLProtocol.self]
        let client = NOWAPIClient(
            environment: APIEnvironment(baseURL: URL(string: "https://now.test")!),
            session: URLSession(configuration: configuration),
            tokenStore: tokenStore
        )
        let state = AppState(apiClient: client)
        state.activeMatch = Match(
            id: matchID,
            profile: makePoint(state: .interested).profile,
            status: .active,
            myFirstLoopSent: true,
            theirFirstLoopReceived: true,
            meetingStatus: .none
        )

        state.cancelMatch()
        state.cancelMatch()

        for _ in 0..<100 where state.isCancellingMatch {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(
            ReopenMatchURLProtocol.requestCount(path: "/matches/\(matchID.uuidString)/cancel"),
            1
        )
        XCTAssertNil(state.activeMatch)
    }

    func testReconnectShowsCloseKindlyNoticeOnceAndKeepsMatchCleared() async throws {
        let matchID = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee")!
        let defaultsKey = "now.acknowledged-close-kindly-match-ids"
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: defaultsKey) }

        let tokenStore = InMemoryAuthTokenStore()
        await tokenStore.setAccessToken("test-token")
        ReopenMatchURLProtocol.reset()
        ReopenMatchURLProtocol.handler = { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/matches/active/detail"):
                return Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "match_item": null,
                      "close_notice": {
                        "match_id": "\(matchID.uuidString)",
                        "reason": "closed_kindly",
                        "message": "Sorry, I can’t meet"
                      }
                    }
                    """
                )
            case ("GET", "/discover/map"):
                return Self.jsonResponse(
                    for: request,
                    body: #"{"radius_m":50000,"discovery_locked":false,"points":[]}"#
                )
            default:
                throw URLError(.badURL)
            }
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReopenMatchURLProtocol.self]
        let client = NOWAPIClient(
            environment: APIEnvironment(baseURL: URL(string: "https://now.test")!),
            session: URLSession(configuration: configuration),
            tokenStore: tokenStore
        )
        let state = AppState(apiClient: client)
        state.refreshActiveMatch()

        for _ in 0..<100 where state.isLoading || state.matchCloseNoticeMessage == nil {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertNil(state.activeMatch)
        XCTAssertEqual(state.matchCloseNoticeMessage, "Sorry, I can’t meet")
        state.acknowledgeMatchCloseNotice()
        state.refreshActiveMatch()
        for _ in 0..<100 where state.isLoading {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNil(state.matchCloseNoticeMessage)
    }

    private func makePoint(
        state: MapPointState,
        alreadyMatched: Bool = false,
        lastMatchID: UUID? = nil
    ) -> MapPoint {
        let profile = UserProfile(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Nearby",
            age: 30,
            distance: "800 m",
            plans: [.coffee],
            intents: [.friendly],
            occupation: "",
            languages: [],
            interests: [],
            sharedInterests: [],
            prompt: "",
            mainPhotoURL: nil,
            introLoopURL: nil
        )

        return MapPoint(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            profile: profile,
            approximateCoordinate: CLLocationCoordinate2D(latitude: -8.648, longitude: 115.139),
            state: state,
            alreadyMatched: alreadyMatched,
            lastMatchID: lastMatchID
        )
    }

    nonisolated private static func jsonResponse(
        for request: URLRequest,
        body: String
    ) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(body.utf8))
    }
}

extension DiscoveryMapNavigationTests {
    func testLikeSendsSelectedMeetingPlaceMetadata() async throws {
        let tokenStore = InMemoryAuthTokenStore()
        await tokenStore.setAccessToken("test-token")
        ReopenMatchURLProtocol.reset()
        ReopenMatchURLProtocol.handler = { request in
            Self.jsonResponse(
                for: request,
                body: """
                {
                  "profile_id": "11111111-1111-1111-1111-111111111111",
                  "state": "liked_today",
                  "match_created": false,
                  "match_item": null
                }
                """
            )
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReopenMatchURLProtocol.self]
        let client = NOWAPIClient(
            environment: APIEnvironment(baseURL: URL(string: "https://now.test")!),
            session: URLSession(configuration: configuration),
            tokenStore: tokenStore
        )
        let place = makeVenue(
            id: "apple-maps-place-id",
            category: .beach,
            latitude: -8.6478
        )

        _ = try await client.likeProfile(
            UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            meetingPlace: place
        )

        let body = try XCTUnwrap(ReopenMatchURLProtocol.latestRequestBody())
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let meetingPlace = try XCTUnwrap(json["meeting_place"] as? [String: Any])
        XCTAssertEqual(meetingPlace["external_id"] as? String, place.externalID)
        XCTAssertEqual(meetingPlace["category"] as? String, "beach")
        XCTAssertEqual(meetingPlace["name"] as? String, place.name)
        XCTAssertEqual(meetingPlace["address"] as? String, place.address)
        XCTAssertEqual(meetingPlace["lat"] as? Double, place.coordinate.latitude)
        XCTAssertEqual(meetingPlace["lng"] as? Double, place.coordinate.longitude)
    }

    func testVenueConfigurationCoversRequiredMeetingCategories() {
        let configured = Set(VenueDiscoveryConfig.searches.flatMap(\.categories))

        XCTAssertTrue(configured.contains(.cafe))
        XCTAssertTrue(configured.contains(.restaurant))
        XCTAssertTrue(configured.contains(.nightlife))
        XCTAssertTrue(configured.contains(.hotel))
        XCTAssertTrue(configured.contains(.beach))
        XCTAssertTrue(configured.contains(.park))
        XCTAssertTrue(configured.contains(.store))
        XCTAssertTrue(configured.contains(.museum))
        XCTAssertTrue(configured.contains(.fitnessCenter))
        XCTAssertTrue(configured.contains(.publicTransport))
        XCTAssertEqual(VenueDiscoveryConfig.searchRadiusM, 5_000)
    }

    func testOnlySupportedPublicPOICategoriesCanBeSelectedFromAppleMapsLayer() {
        for category in [
            MKPointOfInterestCategory.cafe,
            .restaurant,
            .hotel,
            .nightlife,
            .beach,
            .park,
            .store,
            .museum,
            .fitnessCenter,
            .publicTransport,
        ] {
            XCTAssertTrue(
                VenueDiscoveryConfig.supports(category),
                "Expected \(category.rawValue) to be selectable"
            )
        }

        XCTAssertFalse(VenueDiscoveryConfig.supports(.fireStation))
        XCTAssertFalse(VenueDiscoveryConfig.supports(.police))
        XCTAssertFalse(VenueDiscoveryConfig.supports(nil))
    }

    func testAppleMapsHotelResolvesToCompleteMeetingPlace() throws {
        let coordinate = CLLocationCoordinate2D(latitude: -8.6478, longitude: 115.1385)
        let placemark = MKPlacemark(
            coordinate: coordinate,
            addressDictionary: [
                "Street": "12 Batu Bolong Street",
                "City": "Canggu",
                "Country": "Indonesia",
            ]
        )
        let item = MKMapItem(placemark: placemark)
        item.name = "Canggu Beach Hotel"
        item.pointOfInterestCategory = .hotel

        let place = try XCTUnwrap(MeetingPlace.from(item))

        XCTAssertEqual(place.name, "Canggu Beach Hotel")
        XCTAssertEqual(place.category, .hotel)
        XCTAssertFalse(place.externalID.isEmpty)
        XCTAssertFalse(place.address.isEmpty)
        XCTAssertEqual(place.coordinate.latitude, coordinate.latitude)
        XCTAssertEqual(place.coordinate.longitude, coordinate.longitude)
    }

    func testVenueResultsDeduplicateAndRespectMarkerLimit() {
        let center = CLLocationCoordinate2D(latitude: -8.6478, longitude: 115.1385)
        let categories: [MeetingPlaceCategory] = [.cafe, .restaurant, .bar, .beach, .park]
        var places = (0..<40).map { index in
            makeVenue(
                id: "place-\(index)",
                category: categories[index % categories.count],
                latitude: center.latitude + (Double(index) * 0.00001)
            )
        }
        places.append(places[0])

        let processed = VenueResultProcessor.process(places, around: center)

        XCTAssertEqual(processed.count, VenueDiscoveryConfig.resultLimit)
        XCTAssertEqual(Set(processed.map(\.id)).count, processed.count)
        XCTAssertTrue(Set(processed.map(\.category)).isSuperset(of: categories))
    }

    func testCloselyLocatedPOIsRemainDistinctSelectablePlaces() {
        let center = CLLocationCoordinate2D(latitude: -8.6478, longitude: 115.1385)
        let first = makeVenue(id: "cafe-one", category: .cafe, latitude: center.latitude)
        let second = makeVenue(
            id: "cafe-two",
            category: .cafe,
            latitude: center.latitude + 0.000_001
        )

        let processed = VenueResultProcessor.process([first, second], around: center)

        XCTAssertEqual(Set(processed.map(\.id)), [first.id, second.id])
        XCTAssertNotEqual(first, second)
    }

    func testVenueResultsAllowEmptyAppleMapsResponse() async {
        let store = NearbyVenueStore(searcher: StubVenueSearcher(result: .success([])))

        await store.load(around: CLLocationCoordinate2D(latitude: -8.6478, longitude: 115.1385))

        XCTAssertTrue(store.venues.isEmpty)
        XCTAssertFalse(store.shouldOfferRetry)
        XCTAssertTrue(store.diagnostics.isEmpty)
        XCTAssertFalse(store.isLoading)
    }

    func testVenueFullFailureOffersQuietRetryAndCapturesDiagnostics() async {
        let store = NearbyVenueStore(
            searcher: StubVenueSearcher(result: .failure(URLError(.cannotConnectToHost)))
        )

        await store.load(around: CLLocationCoordinate2D(latitude: -8.6478, longitude: 115.1385))

        XCTAssertTrue(store.venues.isEmpty)
        XCTAssertTrue(store.shouldOfferRetry)
        XCTAssertEqual(store.diagnostics.count, VenueDiscoveryConfig.searches.count)
        XCTAssertTrue(store.diagnostics.allSatisfy { $0.domain == NSURLErrorDomain })
        XCTAssertTrue(store.diagnostics.allSatisfy { $0.code == URLError.cannotConnectToHost.rawValue })
        XCTAssertFalse(store.isLoading)
    }

    func testVenuePartialSuccessShowsPlacesWithoutRetry() async {
        let center = CLLocationCoordinate2D(latitude: -8.6478, longitude: 115.1385)
        let venue = makeVenue(id: "partial-place", category: .cafe, latitude: center.latitude)
        let store = NearbyVenueStore(searcher: PartialVenueSearcher(successfulQuery: "Cafe", venue: venue))

        await store.load(around: center)

        XCTAssertEqual(store.venues.map(\.id), [venue.id])
        XCTAssertFalse(store.shouldOfferRetry)
        XCTAssertEqual(store.diagnostics.count, VenueDiscoveryConfig.searches.count - 1)
        XCTAssertFalse(store.isLoading)
    }

    func testVenueFailureKeepsPreviouslyLoadedMarkers() async {
        let center = CLLocationCoordinate2D(latitude: -8.6478, longitude: 115.1385)
        let venue = makeVenue(id: "stable-place", category: .cafe, latitude: center.latitude)
        let searcher = MutableVenueSearcher(result: .success([venue]))
        let store = NearbyVenueStore(searcher: searcher)

        await store.load(around: center)
        searcher.result = .failure(URLError(.networkConnectionLost))
        await store.reload(around: center)

        XCTAssertEqual(store.venues.map(\.id), [venue.id])
        XCTAssertTrue(store.shouldOfferRetry)
        XCTAssertFalse(store.diagnostics.isEmpty)
    }

    func testVenueRetryWhileLoadingDoesNotStartDuplicateSearches() async throws {
        let center = CLLocationCoordinate2D(latitude: -8.6478, longitude: 115.1385)
        let searcher = SlowCountingVenueSearcher()
        let store = NearbyVenueStore(searcher: searcher)

        let initialLoad = Task {
            await store.load(around: center)
        }
        for _ in 0..<100 where await searcher.count() == 0 {
            try await Task.sleep(for: .milliseconds(5))
        }

        await store.reload(around: center)
        await initialLoad.value

        let searchCount = await searcher.count()
        XCTAssertEqual(searchCount, VenueDiscoveryConfig.searches.count)
        XCTAssertFalse(store.isLoading)
    }

    private func makeVenue(
        id: String,
        category: MeetingPlaceCategory,
        latitude: CLLocationDegrees
    ) -> MeetingPlace {
        MeetingPlace(
            externalID: id,
            name: "Place \(id)",
            category: category,
            address: "Address \(id)",
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: 115.1385)
        )
    }
}

private struct StubVenueSearcher: VenueSearching {
    let result: Result<[MeetingPlace], Error>

    func search(
        definition: VenueSearchDefinition,
        region: MKCoordinateRegion
    ) async throws -> [MeetingPlace] {
        _ = definition
        _ = region
        return try result.get()
    }
}

private struct PartialVenueSearcher: VenueSearching {
    let successfulQuery: String
    let venue: MeetingPlace

    func search(
        definition: VenueSearchDefinition,
        region: MKCoordinateRegion
    ) async throws -> [MeetingPlace] {
        _ = region
        if definition.query == successfulQuery {
            return [venue]
        }
        throw URLError(.networkConnectionLost)
    }
}

private final class MutableVenueSearcher: VenueSearching {
    var result: Result<[MeetingPlace], Error>

    init(result: Result<[MeetingPlace], Error>) {
        self.result = result
    }

    func search(
        definition: VenueSearchDefinition,
        region: MKCoordinateRegion
    ) async throws -> [MeetingPlace] {
        _ = definition
        _ = region
        return try result.get()
    }
}

private actor SlowCountingVenueSearcher: VenueSearching {
    private var searchCount = 0

    func search(
        definition: VenueSearchDefinition,
        region: MKCoordinateRegion
    ) async throws -> [MeetingPlace] {
        _ = definition
        _ = region
        searchCount += 1
        try await Task.sleep(for: .milliseconds(20))
        return []
    }

    func count() -> Int {
        searchCount
    }
}

private final class ReopenMatchURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    private static let lock = NSLock()
    private static var requestPaths: [String] = []
    private static var requestBodies: [Data] = []

    static func reset() {
        lock.withLock {
            requestPaths = []
            requestBodies = []
            handler = nil
        }
    }

    static func requestCount(path: String) -> Int {
        lock.withLock { requestPaths.filter { $0 == path }.count }
    }

    static func latestRequestBody() -> Data? {
        lock.withLock { requestBodies.last }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = Self.requestBody(from: request)
        Self.lock.withLock {
            Self.requestPaths.append(request.url?.path ?? "")
            if let body {
                Self.requestBodies.append(body)
            }
        }

        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func requestBody(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }
        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            body.append(buffer, count: count)
        }
        return body.isEmpty ? nil : body
    }
}
