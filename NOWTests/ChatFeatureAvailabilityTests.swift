import XCTest
@testable import NOW

final class ChatFeatureAvailabilityTests: XCTestCase {
    func testTomorrowExtensionIsHiddenFromMatchScreen() {
        XCTAssertFalse(ChatFeatureAvailability.tomorrowExtension)
    }
}
