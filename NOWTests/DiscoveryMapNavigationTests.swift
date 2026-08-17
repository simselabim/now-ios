import CoreLocation
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

    private func makePoint(state: MapPointState) -> MapPoint {
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
            state: state
        )
    }
}
