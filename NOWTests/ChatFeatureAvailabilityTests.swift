import XCTest
@testable import NOW

final class ProductFeatureAvailabilityTests: XCTestCase {
    func testTomorrowExtensionIsHiddenFromMatchScreen() {
        XCTAssertFalse(ProductFeatureAvailability.tomorrowExtension)
    }

    func testNowConfirmationIsHiddenFromMeetingProposalScreen() {
        XCTAssertFalse(ProductFeatureAvailability.meetingProposalNowConfirmation)
    }
}
