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

    func testMapPointEqualityDetectsViewedStateChange() {
        XCTAssertNotEqual(makePoint(state: .unseen), makePoint(state: .viewed))
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

    func testMatchedPointReopensSameMatchOnlyOnceAfterRapidTaps() async throws {
        let matchID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let otherUserID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let tokenStore = InMemoryAuthTokenStore()
        await tokenStore.setAccessToken("test-token")
        ReopenMatchURLProtocol.reset()
        ReopenMatchURLProtocol.handler = { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/matches/\(matchID.uuidString)/reopen"):
                return Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "match_item": {
                        "id": "\(matchID.uuidString)",
                        "user_a_id": "55555555-5555-5555-5555-555555555555",
                        "user_b_id": "\(otherUserID.uuidString)",
                        "other_user_id": "\(otherUserID.uuidString)",
                        "match_date": "2026-08-17",
                        "status": "active",
                        "created_at": "2026-08-17T08:00:00Z",
                        "closed_at": null,
                        "extended_until": null,
                        "extension_accepted_at": null
                      },
                      "reopened": true
                    }
                    """
                )
            case ("GET", "/matches/active/detail"):
                return Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "match_item": {
                        "match_item": {
                          "id": "\(matchID.uuidString)",
                          "user_a_id": "55555555-5555-5555-5555-555555555555",
                          "user_b_id": "\(otherUserID.uuidString)",
                          "other_user_id": "\(otherUserID.uuidString)",
                          "match_date": "2026-08-17",
                          "status": "active",
                          "created_at": "2026-08-17T08:00:00Z",
                          "closed_at": null,
                          "extended_until": null,
                          "extension_accepted_at": null
                        },
                        "other_profile": {
                          "id": "11111111-1111-1111-1111-111111111111",
                          "user_id": "\(otherUserID.uuidString)",
                          "display_name": "Nearby",
                          "birth_date": "1996-01-01",
                          "gender": "woman",
                          "bio": "Hello",
                          "interests": [],
                          "is_publishable": true,
                          "published_at": "2026-08-17T07:00:00Z",
                          "photos": [],
                          "intro_loop": null,
                          "created_at": "2026-08-17T07:00:00Z",
                          "updated_at": "2026-08-17T07:00:00Z"
                        },
                        "other_today_intent": {
                          "id": "66666666-6666-6666-6666-666666666666",
                          "user_id": "\(otherUserID.uuidString)",
                          "intent_date": "2026-08-17",
                          "plans": ["coffee"],
                          "intents": ["friendly"],
                          "times_today": ["now"],
                          "created_at": "2026-08-17T07:00:00Z",
                          "updated_at": "2026-08-17T07:00:00Z"
                        },
                        "loops": [],
                        "chat_unlocked": false,
                        "messages": [],
                        "latest_meeting_proposal": null,
                        "latest_meeting_status": null,
                        "other_meeting_location": null,
                        "meeting_location_config": null,
                        "tomorrow_extension": null,
                        "flags": {
                          "can_send_message": false,
                          "can_create_proposal": false,
                          "can_confirm_we_met": false,
                          "has_confirmed_we_met": false
                        }
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
        state.viewPoint(point)

        for _ in 0..<100 where state.activeMatch == nil {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(state.activeMatch?.id, matchID)
        XCTAssertEqual(state.activeMatch?.profile.id, point.profile.id)
        XCTAssertEqual(ReopenMatchURLProtocol.requestCount(path: "/matches/\(matchID.uuidString)/reopen"), 1)
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
        XCTAssertTrue(configured.contains(.beach))
        XCTAssertTrue(configured.contains(.park))
        XCTAssertTrue(configured.contains(.store))
        XCTAssertTrue(configured.contains(.museum))
        XCTAssertEqual(VenueDiscoveryConfig.searchRadiusM, 5_000)
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

    func testVenueResultsAllowEmptyAppleMapsResponse() async {
        let store = NearbyVenueStore(searcher: StubVenueSearcher(result: .success([])))

        await store.load(around: CLLocationCoordinate2D(latitude: -8.6478, longitude: 115.1385))

        XCTAssertTrue(store.venues.isEmpty)
        XCTAssertNil(store.errorMessage)
        XCTAssertFalse(store.isLoading)
    }

    func testVenueResultsExposeAppleMapsFailure() async {
        let store = NearbyVenueStore(
            searcher: StubVenueSearcher(result: .failure(URLError(.cannotConnectToHost)))
        )

        await store.load(around: CLLocationCoordinate2D(latitude: -8.6478, longitude: 115.1385))

        XCTAssertTrue(store.venues.isEmpty)
        XCTAssertEqual(
            store.errorMessage,
            "Could not reach Apple Maps. Check your internet connection or tap refresh."
        )
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
        XCTAssertNotNil(store.errorMessage)
    }

    func testVenueErrorPresenterDoesNotTreatEmptyResultsAsFailure() {
        XCTAssertNil(VenueSearchErrorPresenter.message(for: []))
        XCTAssertNil(VenueSearchErrorPresenter.message(for: [CancellationError()]))
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
